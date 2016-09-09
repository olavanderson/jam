//
//  DataManager.h
//  Jam
//
//  Created by Olav Anderson on 9/2/16.
//  Copyright © 2016 Gun eTools. All rights reserved.
//

#import <CoreData/CoreData.h>

#ifndef DataManager_h
#define DataManager_h


#endif /* DataManager_h */


@protocol DataManagerDelegate
@optional -(void)fetchedItem:(NSManagedObject *)managedObject;
@optional -(void)fetchedDictionaryItem:(NSDictionary *)dictionary;
@optional -(void)dataFetchError:(NSString *)errorMessage;
@optional -(void)dataFetchError:(NSString *)message withObject:(NSManagedObject *)managedObject;
@optional -(void)dataFetchError:(NSString *)message withEntityName:(NSString *)entityName resourceId:(NSString *)resourceId;
@end

@interface DataManager : NSObject

#define kArticlesURL    @"https://api-proxy.move.com/mvs/articles?client_id=fb_bot"
#define kUserKey        @"User-Key"
#define KUserKeyValue   @"7c19e092434d368300daddd409ce23b9"


#define kBgQueue dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) //1


@property(nonatomic,assign)id delegate;
@property (strong, nonatomic) NSManagedObjectContext        *managedObjectContext;

NSString* encodeToPercentEscapeString(NSString *string);

//+ (void)fetchDataForDelegate:(id)delegate;

- (void) fetchDataForResourceKey:(NSString *)resourceKey;
- (void)createManagedObjectWithFetchedJSON:(NSDictionary *)json;
- (void)createManagedObjectWithFetchedData:(NSData *)someData;


@end