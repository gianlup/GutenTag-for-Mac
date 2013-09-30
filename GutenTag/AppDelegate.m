//
//  AppDelegate.m
//  GutenTag
//
//  Created by Gianluca Puglia on 11/09/13.
//  Copyright (c) 2013 Gianluca Puglia. All rights reserved.
//

#import "AppDelegate.h"

@implementation AppDelegate

void usbDeviceAdded(void *refCon, io_iterator_t iterator) {
    io_object_t thisObject;
    while ((thisObject = IOIteratorNext(iterator))) {
        IOObjectRelease(thisObject);
        [NSThread detachNewThreadSelector:@selector(initGutenTag) toTarget:[GutenTag sharedInstance] withObject:nil];
    }
}

void usbDeviceRemoved(void *refCon, io_iterator_t iterator) {
    io_object_t thisObject;
    while ((thisObject = IOIteratorNext(iterator))) {
        IOObjectRelease(thisObject);
        [(__bridge id)refCon gutenTagNotConnected];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self disableButtons];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gutenTagInitializationFailed) name:@"gutenTagInitializationFailed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gutenTagInitialized) name:@"gutenTagInitialized" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tagIsPresent:) name:@"tagIsPresent" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tagIsNotPresent) name:@"tagIsNotPresent" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(writeError) name:@"writeError" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readError) name:@"readError" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readingDone:) name:@"readingDone" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(writingDone) name:@"writingDone" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(verifyError) name:@"verifyFailed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(verifyDone) name:@"verifyDone" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gutenTagNotConnected) name:@"gutenTagNotConnected" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libUsbInitializationFailed) name:@"libUsbInitializationFailed" object:nil];
    
    io_iterator_t portIterator;
    
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    long vendorID  = 0x04d8;
    long productID = 0xff28;
    
    // Create a CFNumber for the idVendor and set the value in the dictionary
    CFNumberRef numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorID);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), numberRef);
    CFRelease(numberRef);
    
    // Create a CFNumber for the idProduct and set the value in the dictionary
    numberRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productID);
    CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID),  numberRef);
    CFRelease(numberRef);
    numberRef = NULL;
    
    mach_port_t masterPort;
    IOMasterPort(MACH_PORT_NULL, &masterPort);
    
    // Set up notification port and add it to the current run loop for addition notifications.
    IONotificationPortRef notificationPort = IONotificationPortCreate(masterPort);
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       IONotificationPortGetRunLoopSource(notificationPort),
                       kCFRunLoopDefaultMode);
    
    // Register for notifications when a serial port is added to the system.
    // Retain dictionary first because all IOServiceMatching calls consume dictionary.
    CFRetain(matchingDict);
    IOServiceAddMatchingNotification(notificationPort,
                                     kIOMatchedNotification,
                                     matchingDict,
                                     usbDeviceAdded,
                                     (__bridge void *)self,
                                     &portIterator);
    // Run out the iterator or notifications won't start.
    while (IOIteratorNext(portIterator)) {};
    
    // Also Set up notification port and add it to the current run loop removal notifications.
    IONotificationPortRef terminationNotificationPort = IONotificationPortCreate(kIOMasterPortDefault);
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       IONotificationPortGetRunLoopSource(terminationNotificationPort),
                       kCFRunLoopDefaultMode);
    
    // Register for notifications when a serial port is added to the system.
    // Retain dictionary first because all IOServiceMatching calls consume dictionary.
    CFRetain(matchingDict);
    IOServiceAddMatchingNotification(terminationNotificationPort,
                                     kIOTerminatedNotification,
                                     matchingDict,
                                     usbDeviceRemoved,
                                     (__bridge void *)self,
                                     &portIterator);
    
    // Run out the iterator or notifications won't start.
    while (IOIteratorNext(portIterator)) {}; 
    CFRetain(matchingDict);
    
    //Set up Hex View
    [[_hexView controller] setBytesPerColumn:1];
    //[[hexView controller] setFont:[NSFont fontWithName:@"Courier New" size:14]];
    
    HFLayoutRepresenter *layoutRep = [[HFLayoutRepresenter alloc] init];
    [layoutRep setMaximizesBytesPerLine:NO];
    HFLineCountingRepresenter *lineRep = [[HFLineCountingRepresenter alloc] init];
    [lineRep setLineNumberFormat:HFLineNumberFormatHexadecimal];
    [lineRep setMinimumDigitCount:3];
    HFHexTextRepresenter *hexRep = [[HFHexTextRepresenter alloc] init];
    HFVerticalScrollerRepresenter *scrollRep = [[HFVerticalScrollerRepresenter alloc] init];
    
    [[_hexView controller] addRepresenter:layoutRep];
    [[_hexView controller] addRepresenter:hexRep];
    [[_hexView controller] addRepresenter:lineRep];
    [[_hexView controller] addRepresenter:scrollRep];
    
    [layoutRep addRepresenter:hexRep];
    [layoutRep addRepresenter:lineRep];
    [layoutRep addRepresenter:scrollRep];
    
    NSView *layoutView = [layoutRep view];
    [layoutView setFrame:[_hexView bounds]];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [_hexView setLayoutRepresenter:layoutRep];
    [[_hexView controller] setEditable:NO];
    
    [NSThread detachNewThreadSelector:@selector(initGutenTag) toTarget:[GutenTag sharedInstance] withObject:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    [[GutenTag sharedInstance] freeGutenTag];
    return NSTerminateNow;
}

#pragma mark Actions

- (IBAction)loadBin:(id)sender {
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setAllowsMultipleSelection:NO];
    [op setCanChooseDirectories:NO];
    __block NSArray *url;
    [op beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        url = [op URLs];
        if ([url count]) {
            NSString *path = [[url objectAtIndex:0] path];
            tagMemory = [NSData dataWithContentsOfFile:path];
            if ([tagMemory length] == 512) {
                [_hexView setData:tagMemory];
                _statusBar.stringValue = @"Dump Loaded.";
            }
            else {
                _statusBar.stringValue = @"Dump is not valid.";
            }
        }
    }];
}

- (IBAction)saveBin:(id)sender {
    HFByteArray *toWrite = [_hexView byteArray];
    if ([toWrite length] == 512) {
        NSSavePanel *op = [NSSavePanel savePanel];
        [op beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
            if ([op URL] != nil) {
                NSURL *url = [[op URL] URLByAppendingPathExtension:@"bin"];
                HFProgressTracker *pT = [[HFProgressTracker alloc] init];
                [toWrite writeToFile:url trackingProgress:pT error:nil];
                _statusBar.stringValue = @"Dump Saved.";
            }
        }];
    }
    else {
       _statusBar.stringValue = @"Dump is not valid."; 
    }
}

- (IBAction)writeTag:(id)sender {
    _statusBar.stringValue = @"Writing..";
    if ([[_hexView byteArray] length] == 512) {
        [self disableButtons];
        [[GutenTag sharedInstance] performSelectorInBackground:@selector(writeTagMemory:) withObject:[_hexView byteArray]];
    }
    else {
       _statusBar.stringValue = @"Dump is not valid."; 
    }
}

- (IBAction)readTag:(id)sender {
    _statusBar.stringValue = @"Reading..";
    [[GutenTag sharedInstance] performSelectorInBackground:@selector(getTagMemory) withObject:nil];
    [self disableButtons];
}

- (IBAction)verifyTag:(id)sender {
    _statusBar.stringValue = @"Verifying..";
    [[GutenTag sharedInstance] performSelectorInBackground:@selector(verifyTagMemory:) withObject:[_hexView byteArray]];
    [self disableButtons];
}

#pragma mark Notifications

-(void)libUsbInitializationFailed {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"LibUsb Initialization Error");
        _statusBar.stringValue = @"LibUsb Error.";
    });
}

-(void)gutenTagNotConnected {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([scanForTagTimer isValid]) {
            [scanForTagTimer invalidate];
        }
        NSLog(@"GutenTag Disconnected");
        [self disableButtons];
        _statusBar.stringValue = @"GutenTag not Found. Please connect it.";
    });
}

- (void)gutenTagInitializationFailed {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"GutenTag Initialization Error");
        _statusBar.stringValue = @"GutenTag Initialization Error. Please Check it.";
    });
}

- (void)gutenTagInitialized {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"GutenTag ready, waiting for a Tag..");
        _statusBar.stringValue = @"GutenTag Ready! Scan For Tag..";
        [self scheduleTimerForScan];
    });
}

- (void)tagIsPresent:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *uid = [notification object];
        _statusBar.stringValue = [NSString stringWithFormat:@"Tag Found! UID: %@", uid];
        [self enableButtons];
        [scanForTagTimer invalidate];
    });
}

- (void)tagIsNotPresent {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Tag Is Not Present");
        [self disableButtons];
        _statusBar.stringValue = @"Tag Removed! Scan For Tag..";
        [self scheduleTimerForScan];
    });
}

- (void)readingDone:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        tagMemory = (NSData*)[notification object];
        [_hexView setData:tagMemory];
        _statusBar.stringValue = @"Reading Done.";
        [self enableButtons];
    });
    
}

- (void)writingDone {
    dispatch_async(dispatch_get_main_queue(), ^{
        _statusBar.stringValue = @"Writing Done.";
        [self enableButtons];
    });
    
}

- (void)readError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"GutenTag Read Error");
        _statusBar.stringValue = @"Reading Error. Scan For Tag..";
        [self scheduleTimerForScan];
    });
}

- (void)writeError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"GutenTag Write Error");
        _statusBar.stringValue = @"Writing Error. Scan For Tag..";
        [self scheduleTimerForScan];
    });
}

- (void)verifyError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"GutenTag Verify Error");
        _statusBar.stringValue = @"Verify FAIL.";
        [self enableButtons];
    });
}

- (void)verifyDone {
    dispatch_async(dispatch_get_main_queue(), ^{
        _statusBar.stringValue = @"Verify OK.";
        [self enableButtons];
    });
}

#pragma mark Various

- (void)disableButtons {
    [_loadButton setEnabled:NO];
    [_saveButton setEnabled:NO];
    [_writeButton setEnabled:NO];
    [_readButton setEnabled:NO];
    [_verifyButton setEnabled:NO];
    [[_hexView controller] setEditable:NO];
}

- (void)enableButtons {
    [_loadButton setEnabled:YES];
    [_saveButton setEnabled:YES];
    [_writeButton setEnabled:YES];
    [_readButton setEnabled:YES];
    [_verifyButton setEnabled:YES];
    
    [[_hexView controller] setEditable:YES];
}

- (void)scheduleTimerForScan {
    if (![scanForTagTimer isValid]) {
        scanForTagTimer = [NSTimer timerWithTimeInterval:0.5
                                                  target:[GutenTag sharedInstance]
                                                selector:@selector(scanForTagTimerMethod:)
                                                userInfo:nil
                                                 repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:scanForTagTimer forMode:@"NSDefaultRunLoopMode"];
    }
}

@end
