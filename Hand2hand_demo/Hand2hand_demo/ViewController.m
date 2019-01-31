//
//  ViewController.m
//  Hand2hand_demo
//
//  Created by 鲁逸沁 on 2019/1/31.
//  Copyright © 2019年 Yiqin Lu. All rights reserved.
//

#import "ViewController.h"
#import "Classifier.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    Classifier *classifier = [[Classifier alloc] initWithSVM];
    [classifier work];
    
    [self readDataFromBundle:@"log-3-WatchL.txt"];
}



- (void)readDataFromBundle:(NSString *)fileName {
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"MakeBuddle" ofType:@"bundle"]];
    NSString *filePath = [bundle pathForResource:fileName ofType:@"txt"];
    
    NSLog(@"%@", filePath);
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *data = [fileManager contentsAtPath:filePath];
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"%@", [s substringToIndex:10]);
}


@end
