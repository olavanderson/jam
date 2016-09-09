//
//  JSONSetValuesWithKeys.h
//  JSONSetValuesWithKeys
//
//  Created by Olav Anderson on 2014-07-08.
//  Copyright © 2015 olavanderson. All rights reserved.
//

#import <CoreData/NSManagedObject.h>

@interface NSManagedObject (JSONSetValuesWithKeys)

- (void)removeJSONCachedValuesForKeyPath:(NSString *)keyPath;
- (id)valueForRelationshipKey:(NSString *)key;
- (void)safeSetValuesForKeysWithDictionary:(NSDictionary *)keyedValues;
- (void)lazyLoadJSONValuesForRelationshipKey:(NSString *)key;
@end
