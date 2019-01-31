//
//  MachineLearning.m
//  Hand2hand_demo
//
//  Created by Yiqin Lu on 2019/1/31.
//  Copyright © 2019 Yiqin Lu. All rights reserved.
//

#import "Classifier.h"

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
using namespace cv;
using namespace cv::ml;
#endif



@interface Classifier()

@end



@implementation Classifier

- (id)initWithSVM {
    self = [super init];
    
    Ptr<SVM> svm = SVM::create();
    svm->setKernel(SVM::RBF);
    svm->setType(SVM::NU_SVC);
    
    NSLog(@"create classifier");
    return self;
}

- (void)work {
    
}

@end
