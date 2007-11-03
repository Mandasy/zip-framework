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

- (void) testNumberOfZipEntries {
	STAssertTrue([zip numberOfEntries] >= 0, @"Ensure test-archive1.zip contains more then 0 entries");
	STAssertEquals([zip numberOfEntries], 3, @"Number of entries in a zip archive");
}

- (void) testZipEntryInfo {
	NSMutableArray *filesInTest = [NSMutableArray arrayWithObjects:@"test-archive/", @"test-archive/README", @"test-archive/test.txt", nil];
	NSEnumerator *entries = [[zip entries] objectEnumerator];
	id info;
	while ((info = [entries nextObject]) != nil) {
		STAssertTrue([info isKindOfClass:[NSDictionary class]], @"Info should be of type dictionary");
		
		if ([info isKindOfClass:[NSDictionary class]]) {
			NSDictionary *infoDict = (NSDictionary *)info;
			NSString *name = [infoDict objectForKey:@"ZipEntryName"];
			
			STAssertTrue([filesInTest containsObject:name], @"Filename should be known");
			
			[filesInTest removeObject:name];
		}
	}
	
	// check no more files in test
	STAssertEquals((unsigned)0, [filesInTest count], @"All files should be encountered when requesting entry info");
}

- (void) testZipEntryInfoShorthand {
	NSDictionary *info = [zip infoForEntry:@"test-archive/README"];
	
	STAssertEqualObjects([info objectForKey:@"ZipEntryName"], @"test-archive/README", @"Entry name");
	STAssertEqualObjects([info objectForKey:@"ZipEntryUncompressedSize"], [NSNumber numberWithInt:64], @"Uncompressed entry size");
}

- (void) testZipEntryReading {
	FILE *readmeFile;
	char buf[512];
	
	STAssertTrue([zip entryForName:@"non-exising/file.txt"] == NULL, @"Requesting a non-existing file");
	
	readmeFile = [zip entryForName:@"test-archive/README"];
	STAssertFalse(readmeFile == NULL, @"README file should be available in zip");
	
	// read from file, assert contents
	int total_read = 0;
	int len;
	while ((len = fread(&buf, sizeof(char), 512, readmeFile)) > 0) {
		NSLog(@"Read contents into buf");
		total_read += len;
	}
	
	STAssertTrue(total_read > 0, @"Total number of bytes read");
}
@end
