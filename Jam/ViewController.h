//
//  ViewController.h
//  Jam
//
//  Created by Olav Anderson on 9/2/16.
//  Copyright © 2016 Gun eTools. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface ViewController : UITableViewController

-(void)fetchedItem:(NSManagedObject *)managedObject;
@end

