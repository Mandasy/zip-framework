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
	// TODO: read header in single read statement

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
	
	if (header->name_len > 0) {
		header->name = (char *) malloc(sizeof(char) * (header->name_len + 1));
		fread(header->name, header->name_len, 1, fp);
		header->name[header->name_len] = '\0';
	} else {
		header->name = nil;
	}
	
	fseek(fp, header->extra_len, SEEK_CUR); // skip over extra field
	fseek(fp, header->comment_len, SEEK_CUR); // skip over current
}

void readLocalFileHeader(FileHeader *header, FILE *fp) {
	// TODO: read header in single read statement

	header->signature = JKReadUInt32(fp);
	header->min_version = JKReadUInt16(fp);
	header->flag = JKReadUInt16(fp);
	header->compression = JKReadUInt16(fp);
	header->last_mod_time = JKReadUInt16(fp);
	header->last_mod_date = JKReadUInt16(fp);
	header->crc32 = JKReadUInt32(fp);
	header->compressed = JKReadUInt32(fp);
	header->uncompressed = JKReadUInt32(fp);
	header->name_len = JKReadUInt32(fp);
	header->extra_len = JKReadUInt32(fp);
	
	if (header->name_len > 0) {
			header->name = (char *) malloc(sizeof(char) * (header->name_len + 1));
			fread(header->name, header->name_len, 1, fp);
			header->name[header->name_len] = '\0';
	} else {
		header->name = nil;
	}
	
	fseek(fp, header->extra_len, SEEK_CUR); // ignore extra field
}

int ZipArchive_entry_do_read(void *cookie, char *buf, int len) {
	return [((ZipEntryInfo *)cookie)->archive readFromEntry:(ZipEntryInfo *)cookie buffer:buf length:len];
}

@implementation ZipArchive
- (id) initWithFile:(NSString *)location {
	self = [super init];
	
	if (self) {
		file = location;
		central_directory = nil;
		file_count = 0;
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
	if (central_directory == nil) {
		[self readCentralDirectory];
	}

	return file_count;
}

- (NSArray *) entries {
	if (central_directory == nil) {
		[self readCentralDirectory];
	}

	return file_names;
}

- (NSDictionary *) infoForEntry:(NSString *)fileName {
	return nil;
}

- (FILE *) entryForName:(NSString *)fileName {
	CDFileHeader *cd_header = [self CDFileHeaderForFile:fileName];
	if (cd_header == nil) {
		NSLog(@"file not found");
		return NULL;
	} else {
		NSLog(@"File found: %s", cd_header->name);
	}
	
	ZipEntryInfo *entry_io = (ZipEntryInfo *) malloc(sizeof(ZipEntryInfo));
	entry_io->archive = self; // keep track of ziparchive object
	entry_io->fp = fopen([file UTF8String], "r");
	entry_io->read_pos = 0;
	// TODO: check for fp success
	
	fseek(entry_io->fp, cd_header->local_offset, SEEK_SET);
	
	readLocalFileHeader(&(entry_io->file_header), entry_io->fp);
	
	// set offset in file to first compressed data byte
	entry_io->offset_in_file = ftell(entry_io->fp);
	
	// stream for decompression
	entry_io->stream = (z_streamp) malloc(sizeof(z_streamp));
	entry_io->stream->zalloc = Z_NULL;
	entry_io->stream->zfree = Z_NULL; // use default
	entry_io->stream->opaque = 0;
	entry_io->stream->next_in = Z_NULL;
	entry_io->stream->avail_in = 0;
	
	int result = inflateInit(entry_io->stream);
	if (result != Z_OK) {
		NSLog(@"Error setting up decompression stream");
		
		// TODO: free entry_io & stream
		
		return NULL;
	}
	
	// TODO: setup fclose handler
	return fropen((void *)entry_io, ZipArchive_entry_do_read);
}


#pragma mark -
#pragma mark Private method implementation
- (void) readCentralDirectory {
	CDERecord trailer;
	int filesize, trailerPosition;
	FILE *fp = fopen([file UTF8String], "r");
	
	fseek(fp, 0, SEEK_END);
	filesize = (int) ftell(fp);
	
	trailerPosition = zipDiskTrailerInFile(fp, filesize);
	if (trailerPosition < 0) {
		NSLog(@"No disk trailer found in file");
		return;
	}
	
	file_names = [[NSMutableArray alloc] init];
	
	NSLog(@"Trailer found at: %d", trailerPosition);
	
	fseek(fp, trailerPosition, SEEK_SET);
	fread(&trailer, sizeof(CDERecord), 1, fp);
	
	file_count = CFSwapInt16LittleToHost(trailer.nr_files);
	unsigned int cd_pos = CFSwapInt32LittleToHost(trailer.cd_offset);
	
	central_directory = (CDFileHeader *) malloc(sizeof(CDFileHeader) * file_count);
	
	unsigned int i;
	fseek(fp, cd_pos, SEEK_SET);
	for (i=0; i<file_count; i++) {
		readCDFileHeader(&(central_directory[i]), fp);
		[file_names addObject:[NSString stringWithUTF8String:central_directory[i].name]];
	}
	
	fclose(fp);
}

- (int) readFromEntry:(ZipEntryInfo *)entry_io buffer:(char *)buf_out length:(int)len_out {
	char buf_read[512];
	int num_read;

	// goto correct position in zip archive
	fseek(entry_io->fp, entry_io->offset_in_file + entry_io->read_pos, SEEK_SET);

	entry_io->stream->next_out = buf_out; // TODO: correct warning
	entry_io->stream->avail_out = len_out;
	
	while (entry_io->stream->avail_out > 0) {
		num_read = fread(&buf_read, sizeof(char), 512, entry_io->fp);
		
		entry_io->stream->next_in = buf_read; // TODO: correct warning
		entry_io->stream->avail_in = num_read;
		  
		inflate(entry_io->stream, 0);
	}
	
	return -1;
}

- (CDFileHeader *) CDFileHeaderForFile:(NSString *)fileName {
	if (central_directory == nil) {
		[self readCentralDirectory];
	}

	int i;
	const char *name = [fileName UTF8String];
	
	for (i=0; i<file_count; i++) {
		if (strncmp(name, central_directory[i].name, strlen(name)) == 0) {
			return &(central_directory[i]);
		}
	}
	
	return nil;
}

- (void) dealloc {
	if (central_directory != NULL) {
		int i;
		for (i=0; i<file_count; i++) {
			if (central_directory[i].name != nil) {
				free(central_directory[i].name);
			}
		}
		free(central_directory);
	}
	
	
	[file_names release];
	
	[super dealloc];
}
@end
