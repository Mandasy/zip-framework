//
//  ZipArchiveTest.m
//  JKZip
//
//  Created by Joris Kluivers on 3/6/07.
//  Copyright 2007 . All rights reserved.
//

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
