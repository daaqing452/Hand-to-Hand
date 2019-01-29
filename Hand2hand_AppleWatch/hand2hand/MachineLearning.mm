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
    // maybe no need for training, just load external opencv model
    
    SVM *svm = SVM::create();
    svm->setKernel(SVM::RBF);
    svm->setType(SVM::NU_SVC);
    Mat *m = new Mat();
    _InputArray *a = new _InputArray(*m);
    svm->trainAuto(*a, ROW_SAMPLE, *a);
    
    
}

@end
