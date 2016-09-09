//
//  DataManager.m
//  Jam
//
//  Created by Olav Anderson on 9/2/16.
//  Copyright © 2016 Gun eTools. All rights reserved.
//

@import Foundation;
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "DataManager.h"
#import "AppDelegate.h"
#import "NSManagedObject+JSONSetValuesWithKeys.h"

#define ERROR_KEY @"error"

@interface DataManager(private)
- (NSDictionary *)fetchedData:(NSData *)responseData;
- (NSManagedObject *)createManagedObjectWithFetchedData:(NSData *)someData;
@end


@implementation DataManager {
    NSString *_errorMessage;
}

@synthesize delegate                    = _delegate;
@synthesize managedObjectContext        = __managedObjectContext;


- (id) init {
    self = [super init];
    if(nil != self) {
        __managedObjectContext = [(AppDelegate *)[[UIApplication sharedApplication] delegate] managedObjectContext];
    }
    
    return self;
}

- (void)createManagedObjectWithFetchedData:(NSData *)someData
{
    NSError* error;
    NSDictionary* json = [NSJSONSerialization
                          JSONObjectWithData:someData
                          options:kNilOptions
                          error:&error];
    [self createManagedObjectWithFetchedJSON:json];
}

static NSString *DELETEONREFRESH_MODELDIRECTIVE = @"deleteonrefresh";

static NSString *ID_KEY                 = @"id";
static NSString *ROWPREDICAT            = @"(rowid = %@)";
static NSString *INSERTTIME_KEY         = @"inserttime";
static NSString *IDINFOKEYSCACHEDIRECTIVE = @"idinfokeys";


- (void)createManagedObjectWithFetchedJSON:(NSDictionary *)json
{
    if(![json valueForKey:ERROR_KEY]) {
        // NSLog(@"Fetch JSON data: %@", [json valueForKey:@"articles"]);
        //NSLog(@"Fetch JSON data: %@", json);
        NSString *entityName = @"Magazine";//[[[json valueForKey:CLASS_KEY] componentsSeparatedByString:CLASSSEP_KEY] lastObject];
        
        if(!entityName) {
            NSLog(@"No entityName from JSON: %@",json);
            return;
        }
        
        NSDictionary *jsonData = json;//[(NSArray *)[json objectForKey:@"articles"] lastObject];
        
        NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]];
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        [request setEntity:entityDescription];
        NSString *rowid = [json valueForKey:ID_KEY];
        if(!rowid) rowid = @"1";
        NSPredicate *predicate = [NSPredicate predicateWithFormat:ROWPREDICAT, rowid];
        [request setPredicate:predicate];
        
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:INSERTTIME_KEY ascending:YES];
        [request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        
        NSError *error = nil;
        NSArray *array = [[self managedObjectContext] executeFetchRequest:request error:&error];
        
        if (array && [array count] > 0 && [[entityDescription userInfo] valueForKey:DELETEONREFRESH_MODELDIRECTIVE]) {
            NSEnumerator *e = [array objectEnumerator];
            NSManagedObject *anItem;
            while (anItem = [e nextObject]) {
                [[self managedObjectContext] deleteObject:anItem];
            }
            array = nil;
        }
        
        if (array != nil && [array count] > 0) {
            NSEnumerator *e = [array objectEnumerator];
            NSManagedObject *updateItem = nil;
            NSManagedObject *anItem;
            while (anItem = [e nextObject]) {
                //NSLog(@"Found existing: %@", [[array objectAtIndex:0] valueForKey:@"rowid"]);
                //[[self managedObjectContext] deleteObject:anItem];
                //Rather than delete this will update existing managed objects with new data and
                //preserve data that existed but not fetched in the case of a batch vs subbatch fetch
                [anItem  safeSetValuesForKeysWithDictionary:json];
                if(!updateItem) updateItem = anItem;
                // NSLog(@"Update existing ...");
            }
            [self clearManagedObjectContextUserInfo];//Clear out previous fetch data.
            if(updateItem)[self updateDelegate:updateItem withMessage:nil];
        } else {
            NSManagedObject *managedObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:[self managedObjectContext]];
            [managedObject setValue:@"Magazine" forKey:@"name"];
            [managedObject  safeSetValuesForKeysWithDictionary:jsonData];
            [self clearManagedObjectContextUserInfo];//Clear out previous fetch data.
            [self updateDelegate:managedObject withMessage:nil];
        }
        
    } else {
        [self updateDelegate:nil withMessage:[json valueForKey:ERROR_KEY]];
    }
}

- (void)clearManagedObjectContextUserInfo {
    NSArray *keys = [[[[self managedObjectContext] userInfo] valueForKey:IDINFOKEYSCACHEDIRECTIVE] allKeys];
    [[[self managedObjectContext] userInfo] removeObjectsForKeys:keys];
    //Clear keys...
    [[[[self managedObjectContext] userInfo] valueForKey:IDINFOKEYSCACHEDIRECTIVE] removeAllObjects];
}

-(void) fetchDataForResourceKey:(NSString *)resourceKey {
    //NSString *resourceURL = kArticlesURL;
    //NSData* data = [NSData dataWithContentsOfURL: [NSURL URLWithString:resourceURL]];
    NSURL *theURL = [NSURL URLWithString:kArticlesURL];
    NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:theURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:20.0f];
    [theRequest setHTTPMethod:@"GET"];
    
    [theRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [theRequest setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [theRequest setValue:KUserKeyValue forHTTPHeaderField:kUserKey];
    
 //   NSURLResponse *theResponse = NULL;
 //   NSError *theError = NULL;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    //NSURLSessionDataTask *task = [session dataTaskWithRequest:theRequest];
    
    NSURLSessionDataTask *downloadTask = [session
                                          dataTaskWithRequest:theRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                              
                                              if(data && [data length] > 0) {
                                                  
                                                  [self performSelectorOnMainThread:@selector(createManagedObjectWithFetchedData:)
                                                                         withObject:data waitUntilDone:YES];
                                              } else {
                                                  [self updateDelegate:nil withMessage:[NSString stringWithFormat:@"Unable to contact data server."]];
                                              }
                                              
                                              
                                          }];
    
    [downloadTask resume];
    
    //NSData *data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
    
    
}


-(void)updateDelegate:(NSManagedObject *)managedObject withMessage:(NSString *)message
{
    if(!_delegate) {
        NSLog(@"No delegate available...");
    } else
        if(self.delegate && managedObject && [self.delegate respondsToSelector:@selector(fetchedItem:)])
        {
            [self.delegate fetchedItem:managedObject];
        }
    
        else if(nil != message && (self.delegate && [self.delegate respondsToSelector:@selector(dataFetchError: withObject:)])) {
            [self.delegate dataFetchError:message withObject:managedObject];
        }
    
        else if(nil != message && (self.delegate && [self.delegate respondsToSelector:@selector(dataFetchError:)])){
            [self.delegate dataFetchError:message];
        } 
}

@end