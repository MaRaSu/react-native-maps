//
//  AIRMapUrlTileCachedOverlay.m
//  Airmaps
//
//  Created by Markus Suomi on 10/04/2021.
//

#import "AIRMapUrlTileCachedOverlay.h"

@interface AIRMapUrlTileCachedOverlay ()

@end

@implementation AIRMapUrlTileCachedOverlay

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    NSError *error;

    if (!self.tileCachePath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *tileCacheBaseDirectory = [NSString stringWithFormat:@"%@/tileCache", documentsDirectory];
        self.tileCachePath = [NSURL fileURLWithPath:tileCacheBaseDirectory isDirectory:YES];
        NSLog(@"Directory for cached tiles: %@", [self.tileCachePath path]);
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self.tileCachePath path]])
            [[NSFileManager defaultManager] createDirectoryAtPath:[self.tileCachePath path] withIntermediateDirectories:NO attributes:nil error:&error];
        
    }
    
    NSURL *tileCacheFileDirectory = [NSURL URLWithString:[NSString stringWithFormat:@"%d/%d/", (int)path.z, (int)path.x] relativeToURL:self.tileCachePath];
    //NSLog(@"Directory NSURL for tile: %@", [tileCacheFileDirectory path]);
    if (![[NSFileManager defaultManager] fileExistsAtPath:[tileCacheFileDirectory path]]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:[tileCacheFileDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        if (error) NSLog(@"Error: %@", error);
    }

    NSURL *tileCacheFilePath = [NSURL URLWithString:[NSString stringWithFormat:@"%d", (int)path.y] relativeToURL:tileCacheFileDirectory];
    //NSLog(@"Final NSURL for tile: %@", [tileCacheFilePath path]);

    if (![[NSFileManager defaultManager] fileExistsAtPath:[tileCacheFilePath path]]) {
        NSLog(@"tile cache MISS for %d_%d_%d", (int)path.z, (int)path.x, (int)path.y);
        NSURLRequest *request = [NSURLRequest requestWithURL:[self URLForTilePath:path]];
        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            if (result) result(data, connectionError);
            if (!connectionError) [[NSFileManager defaultManager] createFileAtPath:[tileCacheFilePath path] contents:data attributes:nil];
        }];
    } else {
        NSLog(@"tile cache HIT for %d_%d_%d", (int)path.z, (int)path.x, (int)path.y);
        NSLog(@"tile cache HIT, with max age set at %d", self.tileCacheMaxAge);

        // If no cache expiry control set, then when we use a tile, update its modified time so that we can do cache purging for unused tiles
        if (!self.tileCacheMaxAge) {
            if (![[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate:[NSDate date]}
                            ofItemAtPath:[tileCacheFilePath path]
                                    error:&error]) {
                NSLog(@"Couldn't update modification date: %@", error);
            }
        }

        NSData *tile = [NSData dataWithContentsOfFile:[tileCacheFilePath path]];
        if (result) result(tile, nil);

        NSDictionary<NSFileAttributeKey, id> *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[tileCacheFilePath path] error:&error]; 
        if (!fileAttributes) {
            NSLog(@"Couldn't get file attributes for tile file: %@", error);
        } else {
            NSDate *modificationDate = fileAttributes[@"NSFileModificationDate"];
            if (modificationDate) {
                NSLog(@"File age %d", -1 * (int)modificationDate.timeIntervalSinceNow);
                if (-1 * (int)modificationDate.timeIntervalSinceNow > self.tileCacheMaxAge) {
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^ {
                        // This code runs asynchronously!
                        //NSLog(@"Grand central dispatch %f", modificationDate.timeIntervalSinceNow);
                        NSURLRequest *request = [NSURLRequest requestWithURL:[self URLForTilePath:path]];
                        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                            if (!connectionError) {
                                [[NSFileManager defaultManager] createFileAtPath:[tileCacheFilePath path] contents:data attributes:nil];
                                NSLog(@"File refreshed at %@", [tileCacheFilePath path]);
                            }
                        }];
                    });
                }
            }
        }
    }
}

@end