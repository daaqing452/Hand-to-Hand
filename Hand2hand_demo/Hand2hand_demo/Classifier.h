//
//  MachineLearning.h
//  Hand2hand_demo
//
//  Created by Yiqin Lu on 2019/1/31.
//  Copyright © 2019 Yiqin Lu. All rights reserved.
//

#ifndef Classifier_h
#define Classifier_h

#import <UIKit/UIKit.h>

#endif



@interface Classifier : NSObject

@property int type;

- (id)initWithSVM:(NSString *)filePath type:(int)type;
- (int)classify:(NSMutableArray *)features;

@end
