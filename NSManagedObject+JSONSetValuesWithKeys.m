//
//  JSONSetValuesWithKeys.m
//  JSONSetValuesWithKeys
//
//  Created by Olav Anderson on 2014-07-08.
//  Copyright © 2015 olavanderson. All rights reserved.
//

#import "NSManagedObject+JSONSetValuesWithKeys.h"
#import <CoreData/CoreData.h>

@interface  NSManagedObject(private)
- (NSManagedObjectID *)getManagedObjectIDFromData:(NSDictionary *)aDict;
- (void)setManagedObjectIDFor:(NSManagedObjectID *)aManagedObjectID fromData:(NSDictionary *)aDict;
- (void)processToManyArray:(NSArray *)anArray forManagedObject:(NSString *)managedObject relationship:(NSString *) relationship;
@end

@implementation NSManagedObject (JSONSetValuesWithKeys)
/*
 Keys here match what is defined in the EOModel
*/

//Thes keys map to relevannt info in the eomodel(xcdatamoeld)
static NSString *CLASS_FORMAT               = @"com.jam.mobile.%@";
static NSString *INSERTTIME_KEY             = @"inserttime";
static NSString *JSONROWID_KEY              = @"rowid";
static NSString *ROWID_KEY                  = @"id";
static NSString *DATEFORMAT                 = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
static NSString *DATACLASS_KEY              = @"class";
static NSString *IDINFO_KEY                 = @"idinfokeys";

static NSString *UPDATEFETCHPREDICATE_FORMAT= @"(rowid = %@)";
static NSString *JSONLAZYLOADCOUNT_FORMAT   = @"%@count";

//Model directives for entity.
static NSString *JSONRESET_KEY              = @"resetuserinfo";
//Comma seperated list of relationships to be lazy loaded from JSON data.
static NSString *JSONLAZYLOAD_KEY           = @"lazyload";
static NSString *JSONLAZYLOADDELIM          = @",";

static NSString *JSONDATA_KEY               = @"jsondata";
static NSString *JSONDATA_ENTITYNAME_KEY    = @"entityname";
static NSString *JSONDATA_DATA_KEY          = @"data";

- (id)valueForRelationshipKey:(NSString *)key {
    [self lazyLoadJSONValuesForRelationshipKey:key];
    return [self valueForKey:key];
}

- (NSMutableSet *)mutableSetValueForKey:(NSString *)key {
    return [super mutableSetValueForKey:key];
}

- (void)removeJSONCachedValuesForKeyPath:(NSString *)keyPath 
{
    if([[[self entity] userInfo] valueForKey:JSONLAZYLOAD_KEY]) {
        NSArray *lazyLoadCacheRelationships = [[[[self entity] userInfo] valueForKey:JSONLAZYLOAD_KEY] componentsSeparatedByString:JSONLAZYLOADDELIM];
        
        if([lazyLoadCacheRelationships count] > 0) {
            //Get relationship
            NSMutableDictionary *jsonData = [[[[self managedObjectContext] userInfo] valueForKey:JSONDATA_KEY] mutableCopy];
            
            for (NSString *relationship in lazyLoadCacheRelationships) {
                NSMutableDictionary *relationshipData = [[jsonData valueForKey:relationship] mutableCopy];
                NSArray *managedObjects = [self valueForKeyPath:keyPath];
                
                for (NSManagedObject *aManagedObject in managedObjects) {
                    [relationshipData removeObjectForKey:[[aManagedObject valueForKey:JSONROWID_KEY] stringValue]];
                }
                
                [jsonData setValue:relationshipData forKey:relationship];
            }
            
            [[[self managedObjectContext] userInfo] setValue:jsonData forKey:JSONDATA_KEY];
        }
    }
}

- (void)lazyLoadJSONValuesForRelationshipKey:(NSString *)key 
{
    NSMutableDictionary *jsonData = [[[self managedObjectContext] userInfo] valueForKey:JSONDATA_KEY];
    NSDictionary *cachedDataDict = [jsonData valueForKey:key];
    NSMutableDictionary *entityData = [cachedDataDict valueForKey:[[self valueForKey:JSONROWID_KEY] stringValue]];
    if(entityData) {
        NSMutableDictionary *mutableCachedDataDict = [cachedDataDict mutableCopy];
        [self processToManyArray:[entityData valueForKey:JSONDATA_DATA_KEY] forManagedObject:[entityData valueForKeyPath:JSONDATA_ENTITYNAME_KEY] relationship:key];
       
        jsonData =[[[[self managedObjectContext] userInfo] valueForKey:JSONDATA_KEY] mutableCopy];
       
        [mutableCachedDataDict removeObjectForKey:[[self valueForKey:JSONROWID_KEY] stringValue]];
        
        [jsonData setValue:mutableCachedDataDict forKey:key];
        
        [[[self managedObjectContext] userInfo] setValue:jsonData forKey:JSONDATA_KEY];
    }
}

- (void)setNilValueForKey:(NSString *)key {
    [self setValue:[NSNumber numberWithInt:0] forKey:key];
}

- (void) setObject:(id)obj forKey:(id)aKey {
    if(nil == obj) {
         NSLog(@"SetValue: %@ for key: %@",obj, aKey);
    }
    if(nil == aKey) {
        NSLog(@"SetValue: %@ for key: %@",obj, aKey);
    }
     [self setObject:obj forKey:aKey];
}


- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    NSLog(@"SetValue: %@ forUndefinedKey key: %@",value, key);
}


- (id)valueForUndefinedKey:(NSString *)key {
    NSLog(@"@valueForUndefinedKey %@",key);
    return [NSNull null];
}

- (void)safeSetValuesForKeysWithDictionary:(NSDictionary *)keyedValues
{
    NSDictionary *attributes = [[self entity] attributesByName];
    NSDictionary *userInfo = [[self entity] userInfo];
    
    for (NSString *attribute in attributes) {
        id value = nil;
        if([userInfo valueForKey:attribute]) {
            value = [keyedValues objectForKey:[userInfo valueForKey:attribute]];
        } else {
            value = [keyedValues objectForKey:attribute];
        }
        
        if (value == nil) {
            continue;
        }
        
        
        NSAttributeType attributeType = [[attributes objectForKey:attribute] attributeType];
        if ((attributeType == NSStringAttributeType) && ([value isKindOfClass:[NSNumber class]])) {
            value = [value stringValue];
        } else if (((attributeType == NSInteger16AttributeType) || (attributeType == NSInteger32AttributeType) || (attributeType == NSInteger64AttributeType) || (attributeType == NSBooleanAttributeType)) && ([value isKindOfClass:[NSString class]])) {
            value = [NSNumber numberWithInteger:[value integerValue]];
        } else if ((attributeType == NSFloatAttributeType) &&  ([value isKindOfClass:[NSString class]])) {
            value = [NSNumber numberWithDouble:[value doubleValue]];
        } else if ((attributeType == NSDateAttributeType) && ([value isKindOfClass:[NSString class]])) {
            NSDate *aDate = nil;
            NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init] ;
            [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en"]];
            [dateFormatter setDateFormat:DATEFORMAT];
            aDate = [dateFormatter dateFromString:value];
            value = aDate;
        } else if([value isKindOfClass:[NSNull class]]) {
            if(attributeType == NSStringAttributeType) {
                value = @"";
            }
            else if(((attributeType == NSInteger16AttributeType) || (attributeType == NSInteger32AttributeType) || (attributeType == NSInteger64AttributeType) || (attributeType == NSBooleanAttributeType)) ) {
                value = [NSNumber numberWithInteger:0];
            } 
            else if(attributeType == NSDoubleAttributeType) {
                value = [NSNumber numberWithFloat:0.0];
            }
            else if(attributeType == NSFloatAttributeType) {
                value = [NSNumber numberWithDouble:0.0];
            }
            else if(attributeType == NSDateAttributeType) {
                value = nil;
            }
            
        } 
        
        [self setValue:value forKey:attribute];
    }
    
    NSDictionary *relationships = [[self entity] relationshipsByName];
    
    
    for (NSString *relationship in relationships) {
        NSRelationshipDescription *relationshipDesc = [relationships objectForKey:relationship];
        id relationshipClass = nil;
        if([userInfo valueForKey:relationship]) {
            relationshipClass = [userInfo valueForKey:relationship];
            NSDictionary *data = [keyedValues objectForKey:relationship];
            if(![relationshipDesc isToMany] && data) {
                NSManagedObject *aManagedObject = nil;
                NSMutableDictionary *userInfoMOC =[[self managedObjectContext] userInfo];
                NSString *rowID = [[keyedValues valueForKey:ROWID_KEY] stringValue];
                
                //If the relationship data is null. Check for an existing object that this entity could belong to
                //in the object graph. IE back pointer to owning object
                NSString *noGuess = [userInfo valueForKey:[relationship stringByAppendingFormat:@"%@",@"_guess"]];
                
                if([data isKindOfClass:[NSNull class]]) {
                    NSString *objID_Key = [NSString stringWithFormat:CLASS_FORMAT,relationshipClass];
                    NSArray *managedRelationship  = [[userInfoMOC valueForKey:objID_Key] allValues];
                    
                    if(noGuess && ![noGuess boolValue]) {
                        NSLog(@"Skip back pointer guess for relationship: %@",relationship);
                    }
                    else if([managedRelationship count] > 0 ) {
                        aManagedObject = [[self managedObjectContext] objectWithID:[managedRelationship objectAtIndex:0]];//guess...
                    }
                    NSLog(@"Data: %@",data);
                    
                } else {
                    //Get sub object relationships...
                    NSManagedObjectID *objID = [userInfoMOC valueForKey:[data valueForKey:rowID]];
                
                    if(objID) {
                        aManagedObject = [[self managedObjectContext] objectWithID:objID];
                    } else {
                        aManagedObject = [self fetchForUpdate:rowID entityName:relationshipClass];
                        if(nil == aManagedObject) {
                            aManagedObject = [NSEntityDescription insertNewObjectForEntityForName:relationshipClass inManagedObjectContext: [self managedObjectContext]];
                        }
                        if(nil == data){
                           // NSLog(@"aDict is nil!");
                        } else {
                            [self setManagedObjectIDFor:[aManagedObject objectID] fromData:data];
                            [aManagedObject safeSetValuesForKeysWithDictionary:data];
                        }
                    }
                }
                
                [self setValue:aManagedObject forKey:relationship];
                
            } else if([relationshipDesc isToMany]) {
                NSArray *toManyData = [keyedValues objectForKey:relationship];
                NSString *lazyLoad = [[relationshipDesc userInfo] valueForKey:JSONLAZYLOAD_KEY];
                if( ![toManyData isKindOfClass:[NSNull class]] && [toManyData count]) {
                    if(!lazyLoad) {
                        [self processToManyArray:toManyData forManagedObject:relationshipClass relationship:relationship];
                    } else {
                        NSString *countKey = [NSString stringWithFormat:JSONLAZYLOADCOUNT_FORMAT,relationship];
                        NSNumber *intNumber = [NSNumber numberWithInteger:[toManyData count]];
                        [self setValue:intNumber forKey:countKey];
                        [self storeLazyLoadData:toManyData forManagedObject:relationshipClass relationship:relationship]; 
                    }
                }
            }
        } 
    }
    
    if([userInfo valueForKey:JSONRESET_KEY]) {
        [self clearManagedObjectContextUserInfo];
    }
    
}

- (void)storeLazyLoadData:(NSArray *)anArray forManagedObject:(NSString *)managedObject relationship:(NSString *)relationship  
{
    NSMutableDictionary *userInfo = [[self managedObjectContext] userInfo];
    NSMutableDictionary *jsondata = [userInfo valueForKey:JSONDATA_KEY];

    if(!jsondata) {
        jsondata = [NSMutableDictionary dictionaryWithCapacity:1];
        [userInfo setValue:jsondata forKey:JSONDATA_KEY];
    }
    
    NSMutableDictionary *managedObjectRelationshipCache = [jsondata valueForKey:relationship];
    
    if(!managedObjectRelationshipCache) {
        managedObjectRelationshipCache = [NSMutableDictionary dictionaryWithCapacity:1];
        [jsondata setValue:managedObjectRelationshipCache forKey:relationship];
    }
    
    NSString *locationID = [[self valueForKey:JSONROWID_KEY] stringValue];
    
    NSMutableDictionary *managedObjectRelationshipID = [managedObjectRelationshipCache valueForKey:locationID];
    
    if(!managedObjectRelationshipID) {
        managedObjectRelationshipID = [NSMutableDictionary dictionaryWithCapacity:3]; //Three,Three. No more and no less.
        [managedObjectRelationshipCache setValue:managedObjectRelationshipID forKey:locationID];
    }
    
    [managedObjectRelationshipID setValue:anArray forKey:JSONDATA_DATA_KEY];
    [managedObjectRelationshipID setValue:managedObject forKey:JSONDATA_ENTITYNAME_KEY];
}

- (void)clearManagedObjectContextUserInfo {
    NSArray *keys = [[[[self managedObjectContext] userInfo] valueForKey:IDINFO_KEY] allKeys];
    [[[self managedObjectContext] userInfo] removeObjectsForKeys:keys];
}

//Checks for existing object in context to update rather than creating new one with updated data.
//This preserves data from different fetches like batch vs subbatch and allows dynamic fetching
//of releationships such as in the OC Monitor
- (NSManagedObject *)fetchForUpdate:(NSString *)rowid entityName:(NSString *)entityName
{
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entityDescription = [NSEntityDescription entityForName:entityName inManagedObjectContext:[self managedObjectContext]];
    [request setEntity:entityDescription];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:UPDATEFETCHPREDICATE_FORMAT, rowid];
    [request setPredicate:predicate];
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:INSERTTIME_KEY ascending:YES];
    [request setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
    NSError *error = nil;
    NSArray *array = [[self managedObjectContext] executeFetchRequest:request error:&error];
    return [array lastObject];
}

- (void)processToManyArray:(NSArray *)anArray forManagedObject:(NSString *)managedObject relationship:(NSString *)relationship 
{
    for (NSDictionary *aDict in anArray) {
        if(![aDict isKindOfClass:[NSNull class]]) {
            NSManagedObject *aManagedObject = nil;
            NSManagedObjectID *objID = [self getManagedObjectIDFromData:aDict];
            if(objID) {
                aManagedObject = [[self managedObjectContext] objectWithID:objID];
            } else {
                aManagedObject = [self fetchForUpdate:[aDict valueForKey:ROWID_KEY] entityName:managedObject];
                if(nil == aManagedObject) {
                    aManagedObject = [NSEntityDescription insertNewObjectForEntityForName:managedObject inManagedObjectContext: [self managedObjectContext]];
                }
                
                if(nil == aDict){
                   // NSLog(@"aDict is nil!");
                }
                [self setManagedObjectIDFor:[aManagedObject objectID] fromData:aDict];
                [aManagedObject safeSetValuesForKeysWithDictionary:aDict];
            }
          
            NSSet *values = [self valueForKey:relationship];
            if(![values containsObject:aManagedObject]){
                [self setValue:[values setByAddingObject:aManagedObject] forKey:relationship];
            }
            
        }
    }
}

//To make sure objects with same id's don't collide
- (NSManagedObjectID *)getManagedObjectIDFromData:(NSDictionary *)aDict {
    NSMutableDictionary *userInfo = [[self managedObjectContext] userInfo];
    NSMutableDictionary *idInfo = [userInfo valueForKey:[aDict valueForKey:DATACLASS_KEY]];
    
    return (idInfo)?[idInfo valueForKey:[[aDict valueForKey:ROWID_KEY] stringValue]]:nil;
}

- (void)setManagedObjectIDFor:(NSManagedObjectID *)aManagedObjectID fromData:(NSDictionary *)aDict {
    NSMutableDictionary *userInfo = [[self managedObjectContext] userInfo];
    NSMutableDictionary *idInfo = [userInfo valueForKey:[aDict valueForKey:DATACLASS_KEY]];
    NSMutableDictionary      *idInfoKeys = [userInfo valueForKey:IDINFO_KEY];
    
    if(!idInfoKeys) {
        idInfoKeys = [NSMutableDictionary dictionaryWithCapacity:1];
        [userInfo setValue:idInfoKeys forKey:IDINFO_KEY];
    }
    
    if(!idInfo) {
        idInfo = [NSMutableDictionary dictionaryWithCapacity:1];
        [userInfo setValue:idInfo forKey:[[aManagedObjectID entity] name]];
        //[idInfoKeys setValue:[aDict valueForKey:DATACLASS_KEY] forKey:[aDict valueForKey:DATACLASS_KEY]];
        [idInfoKeys setValue:[[aManagedObjectID entity] name] forKey:[[aManagedObjectID entity] name]];
    }
    
    if([[aDict valueForKey:ROWID_KEY] isKindOfClass:[NSNull class]]) {
        NSLog(@"null!");   //Null, definitely null.
    }
    
    NSDictionary *entityUserInfo = [[aManagedObjectID entity] userInfo];
    NSString *rowIdKey = [entityUserInfo valueForKey:ROWID_KEY];
    
    //Hack for demo...
    NSString *rowid = @"10";
    if([aDict valueForKey:rowIdKey]) {
        rowid = [aDict objectForKey:rowIdKey];
    }
    [idInfo setValue:aManagedObjectID forKey:rowid];
}


@end
