/*
 * Zip.framework
 * Copyright 2007, Joris Kluivers
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice, 
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products 
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <stdlib.h>
#import <stdio.h>

#import "zlib.h"

#import "ZipArchive.h"
#import "ZipArchive+PrivateAPI.h"

uint16_t JKReadUInt16(FILE *fp) {
	uint16_t n;
	
	fread(&n, sizeof(uint16_t), 1, fp);
	
	return CFSwapInt16LittleToHost(n);
}

uint32_t JKReadUInt32(FILE *fp) {
	uint32_t n;
	
	fread(&n, sizeof(uint32_t), 1, fp);
	
	return CFSwapInt32LittleToHost(n);
}

BOOL isDiskTrailer(char *start) {
	return (*(start+1) == 0x4b) && (*(start+2) == 0x05) && (*(start+3) == 0x06);
}

int zipDiskTrailerInFile(FILE *fp, int size) {
	char *buffer = (char *) calloc(ZIP_BUFF_SIZE, sizeof(char));
	int offset, buflen, trailerPosition;
	
	// Loop thru the zip file from the end backwards, ZIP_BUFF_SIZE bytes a time to find
	// the ZIP_DISK_TRAILER
	offset = size;
	buflen = 0;
	trailerPosition = -1;
	
	while (offset > 0) {
		offset -= ZIP_BUFF_SIZE;
		offset += 20; // keep some overlap
		buflen = ZIP_BUFF_SIZE;
	
		if (offset < 0) {
			offset = 0;
		}
		
		if (offset + buflen > size) {
			buflen = size - offset;
		}
		
		fseek(fp, offset, SEEK_SET);
		fread(buffer, sizeof(char), buflen, fp);
		
		// loop thru buf to find byte marker
		char *pos;
		for (pos = buffer + buflen; pos >= buffer; pos--) {
			if (*pos == 0x50 && isDiskTrailer(pos)) {
				trailerPosition = offset + (pos - buffer);
				goto positionBreak;
			}
		} 
	}
	
	positionBreak:
	
	free(buffer);
	return trailerPosition;
}

void readCDFileHeader(CDFileHeader *header, FILE *fp) {
	header->signature = JKReadUInt32(fp);
	header->made_by = JKReadUInt16(fp);
	header->min_version = JKReadUInt16(fp);
	header->flag = JKReadUInt16(fp);
	header->compression = JKReadUInt16(fp);
	header->last_mod_time = JKReadUInt16(fp);
	header->last_mod_date = JKReadUInt16(fp);	
	header->crc = JKReadUInt32(fp);
	header->compressed = JKReadUInt32(fp);
	header->uncompressed = JKReadUInt32(fp);
	header->name_len = JKReadUInt16(fp);
	header->extra_len = JKReadUInt16(fp);
	header->comment_len = JKReadUInt16(fp);
	header->disk_start = JKReadUInt16(fp);
	header->int_attr = JKReadUInt16(fp);
	header->ext_attr = JKReadUInt32(fp);
	header->local_offset = JKReadUInt32(fp);
}

int ZipArchive_entry_do_read(void *cookie, char *buf, int len) {
	ZipEntryIO *entry_io = (ZipEntryIO *)cookie;
	
	switch (entry_io->zip_header->compression) {
		case NoCompression:
			NSLog(@"No compression");
			break;
		case Deflated:
			NSLog(@"Decrompress using zlib");
			break;
		default:
			NSLog(@"Unknown compression");
	}
	
	return [entry_io->archive readFromEntry:entry_io->name buffer:buf length:len];
}

@implementation ZipArchive
- (id) initWithFile:(NSString *)location {
	self = [super init];
	
	if (self) {
		file = location;
	}
	
	return self;
}

- (NSString *) name {
	return [file lastPathComponent];
}

- (NSString *) path {
	return file;
}

- (int) numberOfEntries {
	if (entries == nil) {
		[self readEntries];
	}

	return (entries == nil) ? -1 : [entries count];
}

- (NSArray *) entries {
	if (entries == nil) {
		[self readEntries];
	}
	
	return entries;
}

- (NSDictionary *) infoForEntry:(NSString *)fileName {
	NSEnumerator *entryEnum = [[self entries] objectEnumerator];
	NSDictionary *entryInfo;
	while ((entryInfo = [entryEnum nextObject]) != nil) {
		if ([[entryInfo objectForKey:@"ZipEntryName"] isEqualToString:fileName]) {
			break;
		}
	}
	
	return entryInfo;
}

- (FILE *) entryForName:(NSString *)fileName {
	if (![[self entries] containsObject:fileName]) {
		return nil;
	}
	
	ZipEntryIO *entry_io = (ZipEntryIO *) malloc(sizeof(ZipEntryIO));
	entry_io->archive = self;
	entry_io->name = [fileName retain];
	entry_io->pos = 0;
	entry_io->zip_header = &(file_headers[[entries indexOfObject:fileName]]);

	return fropen(entry_io, ZipArchive_entry_do_read);
}


#pragma mark -
#pragma mark Private method implementation
- (void) readEntries {
	entries = [[NSMutableArray alloc] init];

	CDERecord trailer;
	int filesize, trailerPosition;
	FILE *fp = fopen([file UTF8String], "rw");
	
	fseek(fp, 0, SEEK_END);
	filesize = (int) ftell(fp);
	
	trailerPosition = zipDiskTrailerInFile(fp, filesize);
	if (trailerPosition < 0) {
		NSLog(@"No disk trailer found in file");
		return;
	}
	
	NSLog(@"Trailer found at: %d", trailerPosition);
	
			
	fseek(fp, trailerPosition, SEEK_SET);
	fread(&trailer, sizeof(CDERecord), 1, fp);
	
	file_count = CFSwapInt16LittleToHost(trailer.nr_files);
	unsigned int cd_pos = CFSwapInt32LittleToHost(trailer.cd_offset);
	
	file_headers = (CDFileHeader *) malloc(sizeof(CDFileHeader) * file_count);
	
	unsigned int i;
	char name[256];
	fseek(fp, cd_pos, SEEK_SET);
	for (i=0; i<file_count; i++) {
		// read header
		// fread(&header, sizeof(CDFileHeader), 1, fp);
		readCDFileHeader(&(file_headers[i]), fp);
		
		fread(&name, file_headers[i].name_len, 1, fp);
		name[file_headers[i].name_len] = '\0';
		
		NSMutableDictionary *fileInfo = [NSMutableDictionary dictionary];
		[fileInfo setObject:[NSString stringWithUTF8String:name] forKey:@"ZipEntryName"];
		[fileInfo setObject:[NSNumber numberWithInt:file_headers[i].uncompressed] forKey:@"ZipEntryUncompressedSize"];
		
		[entries addObject:fileInfo];
		
		fseek(fp, file_headers[i].extra_len, SEEK_CUR); // skip over extra field
		fseek(fp, file_headers[i].comment_len, SEEK_CUR); // skip over current
	}
	
	fclose(fp);
}

- (int) readFromEntry:(NSString *)name buffer:(char *)buf length:(int)length {
	NSLog(@"Read from %@", name);
	
	return -1;
}

- (void) dealloc {
	
	
	[super dealloc];
}
@end
