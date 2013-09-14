//
//  GutenTag.m
//  GutenTag
//
//  Created by Gianluca Puglia on 08/09/13.
//  Copyright (c) 2013 Gianluca Puglia. All rights reserved.
//

#import "GutenTag.h"

@implementation GutenTag

static struct libusb_device_handle *devh = NULL;

+ (GutenTag *)sharedInstance {
    static GutenTag *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[GutenTag alloc] init];
    });
    return _sharedInstance;
}

- (void)scanForTagTimerMethod:(NSTimer *)timer {
    if (isTagPresent()) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"tagIsPresent" object:getTagUID()];
    }
}

- (void)getTagMemory {
    NSMutableData *data = [[NSMutableData alloc] init];
    for (u_int8_t i=0; i<128; i++) {
        if (isTagPresent()) {
            u_int8_t *block = readTagBlock(i);
            if (block != NULL) {
                [data appendBytes:block length:4];
                free(block);
            }
            else {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"readError" object:nil];
                return;
            }
        }
        else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"tagIsNotPresent" object:nil];
            return;
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"readingDone" object:data];
    return;
}

- (void)writeTagMemory:(HFByteArray *)tagMemory {
    unsigned char array[512];
    HFRange range;
    range.location = 0;
    range.length = 512;
    [tagMemory copyBytes:array range:range];
    for (u_int8_t i=0; i<128; i++) {
        if (isTagPresent()) {
            unsigned char buffer[4];
            buffer[0]=array[i*4];
            buffer[1]=array[i*4+1];
            buffer[2]=array[i*4+2];
            buffer[3]=array[i*4+3];
            if (writeTagBlock(i, buffer[0], buffer[1], buffer[2], buffer[3]) != 0) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"writeError" object:nil];
                return;
            }
        }
        else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"tagIsNotPresent" object:nil];
            return;
        }
        usleep(15000);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"writingDone" object:nil];
}

- (void)verifyTagMemory:(HFByteArray *)tagMemory {
    unsigned char array[512];
    HFRange range;
    range.location = 0;
    range.length = 512;
    [tagMemory copyBytes:array range:range];
    for (u_int8_t i=0; i<128; i++) {
        if (isTagPresent()) {
            u_int8_t *block = readTagBlock(i);
            if (block != NULL) {
                for (u_int8_t j=0; j<4; j++) {
                    if (array[i*4+j] != block[j]) {
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"verifyFailed" object:nil];
                        return;
                    }
                }
                free(block);
            }
            else {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"readError" object:nil];
                return;
            }
        }
        else {
            [[NSNotificationCenter defaultCenter] postNotificationName:@"tagIsNotPresent" object:nil];
            return;
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:@"verifyDone" object:nil];
    return;
}

#pragma mark Internals

static u_int8_t writeTagBlock(u_int8_t addr, u_int8_t d0, u_int8_t d1, u_int8_t d2, u_int8_t d3) {
    int transferred = 0;
    u_int8_t *istr;
    istr = malloc(6 * sizeof(u_int8_t));
    istr[0] = 0x04;
    istr[1] = addr;
    istr[2] = d0;
    istr[3] = d1;
    istr[4] = d2;
    istr[5] = d3;
    int r = libusb_bulk_transfer(devh, (1 | LIBUSB_ENDPOINT_OUT), istr, 6, &transferred, 2000);
    if (r != 0) {
        free(istr);
        return -1;
    }
    free(istr);
    
    u_int8_t *data;
    data = malloc(1 * sizeof(u_int8_t));
    r = libusb_bulk_transfer(devh, (129 | LIBUSB_ENDPOINT_IN), data, 1, &transferred, 1000);
    if (r == 0 && transferred == 1) {
        free(data);
        return 0;
    }
    free(data);
    return -1;
}

static u_int8_t* readTagBlock(u_int8_t addr) {
    int transferred = 0;
    u_int8_t *istr;
    istr = malloc(2 * sizeof(u_int8_t));
    istr[0] = 0x03;
    istr[1] = addr;
    int r = libusb_bulk_transfer(devh, (1 | LIBUSB_ENDPOINT_OUT), istr, 2, &transferred, 2000);
    if (r != 0) {
        free(istr);
        return NULL;
    }
    free(istr);
    
    u_int8_t *data;
    data = malloc(4 * sizeof(u_int8_t));
    r = libusb_bulk_transfer(devh, (129 | LIBUSB_ENDPOINT_IN), data, 4, &transferred, 1000);
    if (r == 0 && transferred == 4) {
        return data;
    }
    free(data);
    return NULL;
}

static NSString* getTagUID(void) {
    int transferred = 0;
    u_int8_t *istr;
    istr = malloc(1 * sizeof(u_int8_t));
    istr[0] = 0x02;
    int r = libusb_bulk_transfer(devh, (1 | LIBUSB_ENDPOINT_OUT), istr, 1, &transferred, 2000);
    if (r != 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"writeError" object:nil];
    }
    free(istr);
    
    u_int8_t *data;
    data = malloc(8 * sizeof(u_int8_t));
    r = libusb_bulk_transfer(devh, (129 | LIBUSB_ENDPOINT_IN), data, 8, &transferred, 1000);
    if (r == 0 && transferred == 8) {
        NSString *uid = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x\n",data[7],data[6],data[5],data[4],data[3],data[2],data[1],data[0]];
        free(data);
        return uid;
    }
    free(data);
    [[NSNotificationCenter defaultCenter] postNotificationName:@"readError" object:nil];
    return NULL;
}

static int isTagPresent(void) {
    int transferred = 0;
    u_int8_t *istr;
    istr = malloc(1 * sizeof(u_int8_t));
    istr[0] = 0x01;
    int r = libusb_bulk_transfer(devh, (1 | LIBUSB_ENDPOINT_OUT), istr, 1, &transferred, 2000);
    if (r != 0) {
        NSLog(@"Write Error: %d\n",r);
        return 0;
    }
    free(istr);
    
    u_int8_t *data;
    data = malloc(1 * sizeof(u_int8_t));
    r = libusb_bulk_transfer(devh, (129 | LIBUSB_ENDPOINT_IN), data, 1, &transferred, 1000);
    if (r == 0 && transferred == 1) {
        if (data[0] == 1) {
            free(data);
            return 1;
        }
        else {
            free(data);
            return 0;
        }
    }
    free(data);
    return 0;
}

#pragma mark Connection Management

- (void)initGutenTag {
    int result = 0;
    result = libusb_init(NULL);
    if(result < 0) {
        NSLog(@"Usb Init Error");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"libUsbInitializationFailed" object:nil];
        return;
    }
    
    result = checkGutenTagConnection();
    if(!result) {
		NSLog(@"Could not find GutenTag");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"gutenTagNotConnected" object:nil];
        return;
	}
    
    libusb_device *found = NULL;
    int f = 0;
    while (!f) {
        libusb_device **list;
        ssize_t cnt = libusb_get_device_list(NULL, &list);
        for (ssize_t i = 0; i < cnt; i++) {
            libusb_device *dev = list[i];
            struct libusb_device_descriptor desc;
            libusb_get_device_descriptor(dev, &desc);
            struct libusb_config_descriptor *config;
            libusb_get_config_descriptor(dev, 0, &config);
            if (desc.idVendor == 0x04d8 && desc.idProduct == 0xff28) {
                found=dev;
                f=1;
            }
            libusb_free_config_descriptor(config);
            //printf("%04x:%04x (bus %d, device %d)\n", desc.idVendor, desc.idProduct, libusb_get_bus_number(dev), libusb_get_device_address(dev));
        }
        libusb_free_device_list(list, 1);
        usleep(100000);
    }

    result = libusb_open(found, &devh);
	if(result) {
		NSLog(@"Could not open GutenTag usb");
        [[NSNotificationCenter defaultCenter] postNotificationName:@"gutenTagInitializationFailed" object:nil];
        libusb_close(devh);
        libusb_exit(NULL);
        return;
	}
    result = libusb_claim_interface(devh, 0);
	if(result < 0) {
		NSLog(@"Usb_claim_interface Error %d", result);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"gutenTagInitializationFailed" object:nil];
        libusb_close(devh);
        libusb_exit(NULL);
        return;
	}
    [[NSNotificationCenter defaultCenter] postNotificationName:@"gutenTagInitialized" object:nil];
    return;
}

- (void)freeGutenTag {
    if (devh != NULL) {
        int result;
        result = libusb_release_interface(devh, 0);
        if(result != 0) {
            NSLog(@"Cannot Release Interface");
            return;
        }
        NSLog(@"Released Interface\n");
    }
	libusb_close(devh);
	libusb_exit(NULL);
    return;
}

u_int8_t checkGutenTagConnection(void) {
    
    io_iterator_t iter;
    kern_return_t kr;
    io_service_t device;
    
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);    // Interested in instances of class
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
    
    // Now we have a dictionary, get an iterator.
    kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iter);
    if (kr != KERN_SUCCESS)
        return -1;
    
    u_int8_t found = 0;
    // iterate
    while ((device = IOIteratorNext(iter))) {
        io_name_t       deviceName;
        CFStringRef     deviceNameAsCFString;
        CFStringRef     gutenTagAsCFString;
        
        kr = IORegistryEntryGetName(device, deviceName);
        if (KERN_SUCCESS != kr) {
            deviceName[0] = '\0';
        }
        
        deviceNameAsCFString = CFStringCreateWithCString(kCFAllocatorDefault, deviceName,
                                                         kCFStringEncodingASCII);
        
        gutenTagAsCFString = CFStringCreateWithCString(kCFAllocatorDefault, "GutenTAG RFID Development Board",
                                                       kCFStringEncodingASCII);
        
        CFComparisonResult res = CFStringCompare(deviceNameAsCFString, gutenTagAsCFString, 0);
        if (res == kCFCompareEqualTo) {
            fprintf(stderr, "GutenTag: ");
            CFShow(deviceNameAsCFString);
            found = 1;
        }
        
        IOObjectRelease(device);
        CFRelease(deviceNameAsCFString);
        CFRelease(gutenTagAsCFString);
    }
    
    // Done, release the iterator 
    IOObjectRelease(iter);
    
    return found;
}

/*static void device_spec(void) {
    struct libusb_device *dev;
    dev = libusb_get_device(devh);
    struct libusb_device_descriptor desc;
    libusb_get_device_descriptor(dev, &desc);
    struct libusb_config_descriptor *config;
    libusb_get_config_descriptor(dev, 0, &config);
    printf("%04x:%04x (bus %d, device %d)\n", desc.idVendor, desc.idProduct, libusb_get_bus_number(dev), libusb_get_device_address(dev));
    const struct libusb_interface *inter;
    const struct libusb_interface_descriptor *interdesc;
    const struct libusb_endpoint_descriptor *epdesc;
    for(int i=0; i<(int)config->bNumInterfaces; i++) {
        inter = &config->interface[i];
        printf("Number of alternate settings: %d\n",inter->num_altsetting);
        for(int j=0; j<inter->num_altsetting; j++) {
            interdesc = &inter->altsetting[j];
            printf("Interface Number: %d\n",interdesc->bInterfaceNumber);
            printf("Number of endpoints: %d\n",interdesc->bNumEndpoints);
            for(int k=0; k<(int)interdesc->bNumEndpoints; k++) {
                epdesc = &interdesc->endpoint[k];
                printf("Descriptor Type: %d\n",(int)epdesc->bDescriptorType);
                printf("EP Address: %d\n",(int)epdesc->bEndpointAddress);
            }
        }
    }
}*/

@end
