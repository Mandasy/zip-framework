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

#import "ZipArchiveTest.h"
#import <Zip/ZipArchive.h>

#define README_FILE_LENGTH	64
#define LIPSUM_FILE_LENGTH	12323
#define ENTRIES_IN_ZIP1		4

@implementation ZipArchiveTest
- (void) setUp {
	zipPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test-archive1" ofType:@"zip"];
	zip = [[ZipArchive alloc] initWithFile:zipPath];
	
	STAssertNotNil(zip, @"Initialization of test zip archive object");
}

- (void) tearDown {
	// [zipPath release];
	[zip release];
}

- (void) testInitialization {
	STAssertEqualObjects([zip path], zipPath, @"ZipArchive path");
	STAssertEqualObjects([zip name], @"test-archive1.zip", @"ZipArchive name");
}

- (void) testNonExistingArchive {
	ZipArchive *nonExistingArchive = [[ZipArchive alloc] initWithFile:@"/tmp/FileShouldNotExist.zip"];
	STAssertNil(nonExistingArchive, @"Non existing archive");
	
	if (nonExistingArchive != nil) { // shouldn't be happening, just in case
		[nonExistingArchive release];
	}
}

- (void) testNumberOfZipEntries {
	STAssertEquals([zip numberOfEntries], ENTRIES_IN_ZIP1, @"Number of entries in a zip archive");
}

- (void) testZipEntryInfo {
	NSMutableArray *filesInTest = [NSMutableArray arrayWithObjects:@"test-archive1/", @"test-archive1/README", @"test-archive1/test.txt", @"test-archive1/lipsum.txt", nil];
	NSEnumerator *entries = [[zip entries] objectEnumerator];
	
	id entryName;
	while ((entryName = [entries nextObject]) != nil) {
		/*NSDictionary *infoDict = [zip infoForEntry:entryName];
		
		
		NSString *name = [infoDict objectForKey:@"ZipEntryName"];
		
		STAssertTrue([filesInTest containsObject:name], @"Filename should be known");*/
		
		[filesInTest removeObject:entryName];
	}
	
	// check no more files in test
	STAssertEquals([filesInTest count], (unsigned)0, @"All files should be encountered when requesting entry info");
}

- (void) testSmallZipEntryReading {
	/* Read from readme file. File uncompressed size is 64 bytes */
	char file_contents[README_FILE_LENGTH + 1] = "README\n------\n\nThis archive is used to test the JKZip.framework.";
	FILE *readmeFile;
	char buf[513];
	int res;
	
	STAssertNil((id)[zip entryNamed:@"non-exising/file.txt"], @"Requesting a non-existing file");
	
	readmeFile = [zip entryNamed:@"test-archive1/README"];
	STAssertNotNil((id)readmeFile, @"README file should be available in zip");
	
	// read from file, assert contents
	int len = fread(&buf, sizeof(char), 512, readmeFile);
	STAssertEquals(len, README_FILE_LENGTH, @"Length of data read");
	
	buf[len] = '\0';
	
	int cmp = strncmp((const char *)buf, (const char *)file_contents, README_FILE_LENGTH);
	STAssertEquals(cmp, 0, @"Filecontents do not match");
	
	res = fclose(readmeFile);
	STAssertEquals(res, 0, @"Succesful file close");
}

- (void) testLargeZipEntryReading {
	/*
		Test the readed content of a file with contents larger then a 
		single read buffer
	*/

	int total_read = 0, len = 0, res = 0;
	char buf[512];
	
	FILE *largerFile = [zip entryNamed:@"test-archive1/lipsum.txt"];
	STAssertNotNil((id) largerFile, @"Larger file not found in archive");
	
	if (largerFile != nil) {
		while ((len = fread(buf, sizeof(char), 512, largerFile)) > 0) {
			total_read += len;
		}
	}
	
	STAssertEquals(total_read, LIPSUM_FILE_LENGTH, @"Lenth of lipsum file");
	
	res = fclose(largerFile);
	STAssertEquals(res, 0, @"Close result of larger file");
}

- (void) testFullBufferReads {
	/*
		A test to see if all buffer space is used when reading, to ensure
		the least cycles in a loop are used
	*/
	
	char buf[4096];
	int last_read = LIPSUM_FILE_LENGTH % 4096;
	int num_reads = (LIPSUM_FILE_LENGTH - last_read) / 4096;
	int len = 0, res = 0;
	int total_read = 0;
	
	FILE *lipsum = [zip entryNamed:@"test-archive1/lipsum.txt"];
	
	// do all full reads
	int i=0;
	for (i=0; i<num_reads; i++) {
		len = fread(buf, sizeof(char), 4096, lipsum);
		
		STAssertEquals(len, 4096, @"Full read");
		
		total_read += len;
	}
	
	// left over read
	len = fread(buf, sizeof(char), 4096, lipsum);
	STAssertEquals(len, last_read, @"Left over read");
	total_read += len;
	
	STAssertEquals(total_read, LIPSUM_FILE_LENGTH, @"Lipsum.txt length");
	
	res = fclose(lipsum);
	STAssertEquals(res, 0, @"Close lipsum.txt result");
}

- (void) testOpenEntryTwice {
	char buf[512];
	int len, res;
	int total1, total2;

	FILE *entry1 = [zip entryNamed:@"test-archive1/README"];
	FILE *entry2 = [zip entryNamed:@"test-archive1/README"];
	
	STAssertNotNil((id) entry1, @"First opened entry");
	STAssertNotNil((id) entry2, @"Opened same entry second time");
	
	// read from first entry
	total1 = 0;
	while ((len = fread(buf, sizeof(char), 512, entry1)) > 0) {
		total1 += len;
	}
	
	// read from second entry
	total2 = 0;
	while ((len = fread(buf, sizeof(char), 512, entry2)) > 0) {
		total2 += len;
	}
	
	STAssertEquals(total1, total2, @"Same entry, same content length");
	STAssertEquals(total1, README_FILE_LENGTH, @"Readme file length");
	
	res = fclose(entry1);
	STAssertEquals(res, 0, @"Closing entry 1");
	
	res = fclose(entry2);
	STAssertEquals(res, 0, @"Closing entry 2");
}

- (void) testOpenArchiveTwice {
	char buf[512];
	int len, total1 = 0, total2 = 0;

	FILE *readmeFile1 = [zip entryNamed:@"test-archive1/README"];
	STAssertNotNil((id)readmeFile1, @"Readme file");
	total1 = 0;
	while ((len = fread(buf, sizeof(char), 512, readmeFile1)) > 0) {
		total1 += len;
	}
	
	STAssertEquals(total1, README_FILE_LENGTH, @"README length from first opened archive");

	// open zip archive again
	ZipArchive *zip2 = [[ZipArchive alloc] initWithFile:zipPath];
	STAssertNotNil(zip2, @"Opening test archive for second time");
	
	FILE *readmeFile2 = [zip2 entryNamed:@"test-archive1/README"];
	STAssertNotNil((id)readmeFile2, @"Existing readme file in archive");
	
	while ((len = fread(buf, sizeof(char), 512, readmeFile2)) > 0) {
		total2 += len;
	}
	
	STAssertEquals(total2, README_FILE_LENGTH, @"Readme file length");
	
	[zip2 release];
}

- (void) testOpeningLotsOfZips {
	int i, j;
	NSArray *archives = [NSArray arrayWithObjects:@"test-archive1", @"ZipFramework-0.1-src", nil];
	NSString *archiveName;
	NSString *archivePath;
	NSMutableArray *archiveCollection = [[NSMutableArray alloc] init];
	
	for (i=0; i<[archives count]; i++) {
		archiveName = [archives objectAtIndex:i];
		archivePath = [[NSBundle bundleForClass:[self class]] pathForResource:archiveName ofType:@"zip"];
		
		ZipArchive *archive;
		for (j=0; j<100; j++) {
			// also tests autoreleased object
			archive = [ZipArchive archiveWithFile:archivePath];
			STAssertNotNil(archive, @"Creating archive failed");
			
			[archiveCollection addObject:archive];
		}
	}
	
	STAssertEquals([archiveCollection count], [archives count] * 100, @"Number of zip archives created");
	
	NSEnumerator *files;
	ZipArchive *archive;
	NSString *fileInZip;
	FILE *fileInZipStream;
	for (i=0; i<[archiveCollection count]; i++) {
		archive = (ZipArchive *) [archiveCollection objectAtIndex:i];
		files = [[archive entries] objectEnumerator];
		
		while (fileInZip = (NSString *) [files nextObject]) {
			fileInZipStream = [archive entryNamed:fileInZip];
			
			if (fileInZipStream != NULL) {
				j = fclose(fileInZipStream);
				STAssertEquals(j, 0, @"Closing file stream of: %@", fileInZip);
			}
		}
	}
	
	[archiveCollection release];
}

- (void) testFscanfReading {
	// TODO: see how buffer behaves. What happens if 1 read 1 float, do we decompress 512 bytes?
}

@end
