//
//  GutenTag.h
//  GutenTag
//
//  Created by Gianluca Puglia on 08/09/13.
//  Copyright (c) 2013 Gianluca Puglia. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HexFiend/HexFiend.h"
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include "libusb.h"

@interface GutenTag : NSObject

+ (GutenTag *)sharedInstance;

- (void)initGutenTag;
- (void)freeGutenTag;
- (void)scanForTagTimerMethod:(NSTimer *)timer;
- (void)getTagMemory;
- (void)writeTagMemory:(HFByteArray *)tagMemory;
- (void)verifyTagMemory:(HFByteArray *)tagMemory;

@end
