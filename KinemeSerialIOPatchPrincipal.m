#import <IOKit/serial/ioss.h>
#import <termios.h>
#import "KinemeSerialIOPatchPrincipal.h"
#import "KinemeSerialInput.h"
#import "KinemeSerialOutput.h"

static NSMutableDictionary *deviceDictionary = nil;

int openDevice(NSString *dev, int baudRate, int parity, int dataBits, int stopBits)
{
	int serialDevice = -1;
	
	if(deviceDictionary != nil)
		if([deviceDictionary objectForKey:dev] != nil)
		{
			NSLog(NSLocalizedString(@"KinemeSerialIO: openDevice:  using alread-opened device for %@", @""), dev);
			int useCount = [[deviceDictionary objectForKey:[NSString stringWithFormat:@"%@UseCount",dev]] intValue];
			[deviceDictionary setObject:[NSNumber numberWithInt:(useCount+1)] forKey:[NSString stringWithFormat:@"%@UseCount",dev]];
			serialDevice = [[deviceDictionary objectForKey:dev] intValue];
			return serialDevice;
		}
	NSLog(NSLocalizedString(@"KinemeSerialIO: openDevice: opening %@", @""), dev);
	serialDevice = open([dev cStringUsingEncoding: NSASCIIStringEncoding], O_RDWR | O_NONBLOCK);
	if(serialDevice == -1)
	{
		NSLog(NSLocalizedString(@"KinemeSerialIO: openDevice: open failed for device [%@]: %s", @""), dev,strerror(errno));
		return serialDevice;
	}
	// if we got a device, add it to the dictionary and configure it
	if(serialDevice > -1)
	{
		NSLog(NSLocalizedString(@"KinemeSerialIO: openDevice: Configuring device", @""));
		if(configDevice(serialDevice, baudRate, parity, dataBits, stopBits))
		{
			return -1;	// generic failure. logged in configDevice
		}
		NSLog(NSLocalizedString(@"KinemeSerialIO: openDevice: Configured.  Adding to dictionary.", @""));
		if(deviceDictionary == nil)
			deviceDictionary = [[NSMutableDictionary alloc] initWithCapacity:1];
		[deviceDictionary setObject:[NSNumber numberWithInt:serialDevice] forKey: dev];
		[deviceDictionary setObject:[NSNumber numberWithInt:1] forKey:[NSString stringWithFormat:@"%@UseCount",dev]];
	}
	NSLog(NSLocalizedString(@"KinemeSerialIO: openDevice:  all finished up!", @""));
	return serialDevice;
}

// reconfigure on the fly...
int configDevice(int dev, int baudRate, int parity, int dataBits, int stopBits)
{
	struct termios options;
	int speed = baudRate;
	int serialDevice = dev;
	
	if(ioctl(serialDevice, IOSSIOSPEED, &speed) == -1)
	{
		NSLog(NSLocalizedString(@"KinemeSerialIO: configDevice: Error setting baud rate to %i", @""), speed);
		//return NO;
	}
	NSLog(NSLocalizedString(@"KinemeSerialIO:  %i baud rate configured", @""),speed);
	if(tcgetattr(serialDevice, &options) == -1)
	{
		NSLog(NSLocalizedString(@"KinemeSerialIO: configDevice:  Error getting attributes: %s", @""),strerror(errno));
		//return NO;
	}
//	NSLog(@"KinemeSerialIO: Current Configuration:");
//	NSLog(@"   * Parity: %s",options.c_cflag & PARENB?"Yes":"No");
//	NSLog(@"      * Type: %s",options.c_cflag & PARODD?"Odd":"Even");
//	switch( options.c_cflag & CSIZE )
//	{
//		case CS5:
//			NSLog(@"   * Data Bits:  5 bit");
//			break;
//		case CS6:
//			NSLog(@"   * Data Bits:  6 bit");
//			break;
//		case CS7:
//			NSLog(@"   * Data Bits:  7 bit");
//			break;
//		case CS8:
//			NSLog(@"   * Data Bits:  8 bit");
//			break;
//		default:
//			NSLog(@"   * Data Bits:  Something Weird... (%08x)",options.c_cflag);
//	}
//	NSLog(@"   * Stop Bits: %s", (options.c_cflag & CSTOPB)?"2":"1" );
	
	switch(parity)
	{
		case 0:	// Even
		//	NSLog(@"KinemeSerialIO: configDevice: Enabling Even Parity");
			options.c_cflag |= PARENB;
			options.c_cflag &= ~(PARODD);
			break;
		case 1:	// Odd
		//	NSLog(@"KinemeSerialIO: configDevice: Enabling Odd Parity");
			options.c_cflag |= PARENB;
			options.c_cflag |= PARODD;
			break;
		case 2:	// None
		//	NSLog(@"KinemeSerialIO: configDevice: Disabling Parity");
			options.c_cflag &= ~(PARENB);
			break;
	}
	options.c_cflag &= ~(CSIZE);
	switch(dataBits)
	{
		case 0:	// 5
		//	NSLog(@"KinemeSerialIO: configDevice: Enabling 5 Data Bits (how quaint :)");
			options.c_cflag |= CS5;
			break;
		case 1:	// 6
		//	NSLog(@"KinemeSerialIO: configDevice: Enabling 6 Data Bits");
			options.c_cflag |= CS6;
			break;
		case 2:	// 7
		//	NSLog(@"KinemeSerialIO: configDevice: Enabling 7 Data Bits");
			options.c_cflag |= CS7;
			break;
		case 3:	// 8
		//	NSLog(@"KinemeSerialIO: configDevice: Enabling 8 Data Bits");
			options.c_cflag |= CS8;
			break;
	}
	options.c_cflag &= ~(CSTOPB);
	if(stopBits)
	{
//		NSLog(@"KinemeSerialIO: configDevice: Enabling 2nd Stop Bit");
		options.c_cflag |= CSTOPB;
	}
	// ... disable cannon mode, echoing, and signal stuff
	options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG);
	if(tcsetattr(serialDevice, TCSANOW, &options) == -1)
	{
		NSLog(NSLocalizedString(@"KinemeSerialIO: configDevice: Error configuring device: %s", @""),strerror(errno));
		return 0;
		//return -1;
	}
	return 0;	// no problems
}

void closeDevice(int dev)
{
	NSNumber *useCount;
	NSString *key = [[deviceDictionary allKeysForObject:[NSNumber numberWithInt:dev]] objectAtIndex:0];
	if(key == nil)
	{
		//NSLog(@"KinemeSerialIO: closeDevice: key %i not found... that shouldn't happen?",dev);
		return;
	}
	useCount = [deviceDictionary objectForKey:[NSString stringWithFormat:@"%@UseCount",key]];
	if( [useCount intValue] == 1 )
	{
//		NSLog(@"KinemeSerialIO: closeDevice: Last user of %i closed.  Cleaning up",dev);
		[deviceDictionary removeObjectForKey:[NSString stringWithFormat:@"%@UseCount",key]];
		[deviceDictionary removeObjectForKey:key];
		close(dev);
	}
	else	// not last, just decrement
	{
//		NSLog(@"KinemeSerialIO: closeDevice: 1 user closed, dropping use count from %i",[useCount intValue]);
		[deviceDictionary setObject:[NSNumber numberWithInt:[useCount intValue]-1] forKey:[NSString stringWithFormat:@"%@UseCount",key]];
	}
	if([deviceDictionary count] == 0)
	{
//		NSLog(@"KinemeSerialIO: closeDevice: All devices closed.  Cleaning up.");
		[deviceDictionary release];
		deviceDictionary = nil;
	}
}

@implementation KinemeSerialIOPatchPlugin
+ (void)registerNodesWithManager:(GFNodeManager*)manager
{
	// each pattern checks to see if it's already registered.  Follow the pattern with additional patches.
	if( [manager isNodeRegisteredWithName: [KinemeSerialInput className]] == FALSE )
		[manager registerNodeWithClass:[KinemeSerialInput class]];
	if( [manager isNodeRegisteredWithName: [KinemeSerialOutput className]] == FALSE )
		[manager registerNodeWithClass:[KinemeSerialOutput class]];

}
@end
