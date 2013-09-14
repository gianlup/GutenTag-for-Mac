//
//  AppDelegate.h
//  GutenTag
//
//  Created by Gianluca Puglia on 11/09/13.
//  Copyright (c) 2013 Gianluca Puglia. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOMessage.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#import "GutenTag.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSData *tagMemory;
    NSTimer *scanForTagTimer;
}

@property (weak) IBOutlet NSWindow *window;
@property (strong) IBOutlet HFTextView *hexView;

- (IBAction)loadBin:(id)sender;
- (IBAction)saveBin:(id)sender;

- (IBAction)writeTag:(id)sender;
- (IBAction)readTag:(id)sender;
- (IBAction)verifyTag:(id)sender;

@property (weak) IBOutlet NSButton *loadButton;
@property (weak) IBOutlet NSButton *saveButton;
@property (weak) IBOutlet NSButton *writeButton;
@property (weak) IBOutlet NSButton *readButton;
@property (weak) IBOutlet NSButton *verifyButton;
@property (weak) IBOutlet NSTextField *statusBar;

@end
