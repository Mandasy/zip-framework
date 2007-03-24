//
//  ZipArchiveTest.h
//  JKZip
//
//  Created by Joris Kluivers on 3/6/07.
//  Copyright 2007 . All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>

@class ZipArchive;

@interface ZipArchiveTest : SenTestCase {
	ZipArchive *zip;
	NSString *zipPath;
}

@end
