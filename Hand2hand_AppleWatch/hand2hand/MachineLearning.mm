//
//  MachineLearning.c
//  hand2hand
//
//  Created by Yiqin Lu on 2019/1/24.
//  Copyright © 2019 Yiqin Lu. All rights reserved.
//

#include "MachineLearning.h"

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
using namespace cv;
using namespace cv::ml;
#endif

@interface MachineLearning()

@end


@implementation MachineLearning

- (void)createSVM {
    Ptr<SVM> svm = SVM::create();
    svm->setKernel(SVM::RBF);
    svm->setType(SVM::NU_SVC);
    
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"MakeBuddle" ofType:@"bundle"];
    NSLog(@"%@", bundlePath);
}

@end
