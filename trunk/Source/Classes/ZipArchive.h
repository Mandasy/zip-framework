//
//  ZipArchive.h
//  JKZip
//
//  Created by Joris Kluivers on 3/6/07.
//  Copyright 2007 . All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ZipArchive : NSObject {
	NSString *file;
	NSMutableArray *entries;
}

- (id) initWithFile:(NSString *)location;

- (NSString *) name;
- (NSString *) path;

- (int) numberOfEntries;
- (NSArray *) entries;

- (FILE *) entryForName:(NSString *)fileName;
@end
