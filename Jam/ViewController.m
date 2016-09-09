//
//  ViewController.m
//  Jam
//
//  Created by Olav Anderson on 9/2/16.
//  Copyright © 2016 Gun eTools. All rights reserved.
//

#import "ViewController.h"
#import "CoreData/NSManagedObject.h"
#import "DataManager.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *aLabel;
@property (weak, nonatomic) IBOutlet UITextView *aTextView;

- (void)fetchImage:(NSString *)imgLocation forCel:(UITableViewCell*) cell indexPath:(NSIndexPath *)indexPath;

@end

@implementation ViewController {
    //Private stuff
    NSManagedObject *_managedObject;
    NSMutableDictionary *_imageCache;
    UIImage *_placeHolder;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _imageCache = [[NSMutableDictionary alloc] initWithCapacity:10];
    _placeHolder = [UIImage imageNamed:@"placeholder.png"];
    DataManager *mdc = [[DataManager alloc] init];
    [mdc setDelegate:self];
    
    dispatch_async(kBgQueue, ^{
        [mdc fetchDataForResourceKey:@"test"];
    });
    
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[_managedObject valueForKey:@"articles"] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
   
    /*
    if(cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    */
    NSManagedObject *article = [[[self->_managedObject valueForKey:@"articles"] allObjects] objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [article valueForKey:@"title"];
    cell.detailTextLabel.text = [article valueForKeyPath:@"author.name"];
    cell.imageView.image = _placeHolder;
    if( [self->_imageCache objectForKey:indexPath]) {
        cell.imageView.image = [self->_imageCache objectForKey:indexPath];
    } else {
        [self fetchImage:[article valueForKeyPath:@"featured_image.mobileURL"]forCel:cell indexPath:indexPath];
       
    }
    
    return cell;
}


-(void)fetchedItem:(NSManagedObject *)managedObject {
    NSLog(@"Got Managed Object: %@", managedObject);
    _managedObject = managedObject;
    self.aLabel.text = [_managedObject valueForKey:@"name"];
    //self.aTextView.text = [_managedObject valueForKey:@"body"];
    
    /*
    NSAttributedString *attributedString = [[NSAttributedString alloc]
                                            initWithData: [[_managedObject valueForKey:@"body"] dataUsingEncoding:NSUnicodeStringEncoding]
                                            options: @{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType }
                                            documentAttributes: nil
                                            error: nil
                                            ];
    */
    
    //self.aTextView.attributedText = attributedString;
    
    //NSLog(@"%@", [_managedObject valueForKey:@"excerpt"]);
    [[self tableView] reloadData];
}


- (void)fetchImage:(NSString *)imgLocation forCel:(UITableViewCell*) cell indexPath:(NSIndexPath *)indexPath {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^{
                       //NSLog(@"image: %@",imgLocation);
                       NSURL *imageURL = [NSURL URLWithString:imgLocation];
                       NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
                       
                       //This is your completion handler
                       dispatch_sync(dispatch_get_main_queue(), ^{
                           UIImage *image = [UIImage imageWithData:imageData];
                           cell.imageView.image = image;
                           if(image) {
                               [self->_imageCache setObject:image forKey:indexPath];
                               [[self tableView] reloadRowsAtIndexPaths:[[self tableView]indexPathsForVisibleRows] withRowAnimation:UITableViewRowAnimationNone];
                           }
                           
                       });
                   });
    
    //Any code placed outside of the block will likely
    // be executed before the block finishes.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
