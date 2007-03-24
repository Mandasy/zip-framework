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
	NSEnumerator *entries = [[zip entries] objectEnumerator];
	id info;
	while ((info = [entries nextObject]) != nil) {
		STAssertTrue([info isKindOfClass:[NSDictionary class]], @"Info should be of type dictionary");
		
		if ([info isKindOfClass:[NSDictionary class]]) {
			NSDictionary *infoDict = (NSDictionary *)info;
			NSString *name = [infoDict objectForKey:@"ZipEntryName"];
			if ([name isEqualToString:@"test-archive/README"]) {
				// some tests for test-archive/README
			}
		}
	}
}

- (void) testZipEntryReading {
	FILE *readmeFile;
	char buf[512];
	
	STAssertNil([zip entryForName:@"non-exising/file.txt"], @"Requesting a non-existing file");
	
	readmeFile = [zip entryForName:@"test-archive/README"];
	STAssertNotNil(readmeFile, @"README file should be available in zip");
	
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
