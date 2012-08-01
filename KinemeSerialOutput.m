#import "KinemeSerialOutput.h"
#import <IOKit/serial/ioss.h>
#include <termios.h>

@implementation KinemeSerialOutput : QCPatch

+ (int)executionModeWithIdentifier:(id)fp8
{
	return 1;
}
+ (BOOL)allowsSubpatchesWithIdentifier:(id)fp8
{
	return NO;
}

+ (int)timeModeWithIdentifier:(id)fp8
{
	return 1;
}

- (id)initWithIdentifier:(id)fp8
{
	if(self=[super initWithIdentifier:fp8])
	{
		[[self userInfo] setObject:@"Kineme Serial Output" forKey:@"name"];

		[inputParity setMaxIndexValue:2];
		[inputParity setIndexValue:2];	// None by default
		[inputDataBits setMaxIndexValue:3];
		[inputDataBits setIndexValue:3];	// 8 data bits by default
		[inputStopBits setMaxIndexValue:1];	// 0 is 1 stop bit by default
		[inputBaudRate setIndexValue:9600];	// a standard default :)
		serialDevice = -1;
	}
	return self;
}

- (void)disable:(QCOpenGLContext *)context
{
	if(serialDevice != -1)
		closeDevice(serialDevice);
	serialDevice = -1;
}

static unsigned char unhex(unsigned char t, unsigned char b) __attribute__((pure));
static unsigned char unhex(unsigned char t, unsigned char b)
{
	unsigned char ret = 0;
	
	if(t >= '0' && t <= '9')
		ret |= (t-'0') << 4;
	else if( t>='a' && t<='f' )
		ret |= ((t-'a')+0xa) << 4;
	else if( t>='A' && t<='F' )
		ret |= ((t-'A')+0xa) << 4;

	if(b >= '0' && b <= '9')
		ret |= (b-'0') << 0;
	else if( b>='a' && b<='f' )
		ret |= ((b-'a')+0xa) << 0;
	else if( b>='A' && b<='F' )
		ret |= ((b-'A')+0xa) << 0;
	
	return ret;
}

- (BOOL)execute:(QCOpenGLContext *)context time:(double)time arguments:(NSDictionary *)arguments
{
	// name change.  close/open
	if(	![deviceName isEqualToString:[inputDevice stringValue]] )
	{
		//NSLog(@"KinemeSerialOutput: Opening %@",[inputDevice stringValue]);
		deviceName = [[inputDevice stringValue] copy];
		baudRate = [inputBaudRate indexValue];
		parity = [inputParity indexValue];
		dataBits = [inputDataBits indexValue];
		stopBits = [inputStopBits indexValue];

		if(serialDevice != -1)
			closeDevice(serialDevice);
		serialDevice = openDevice([inputDevice stringValue], baudRate, parity, dataBits, stopBits);
	}
	// configuration change
	if(	baudRate != [inputBaudRate indexValue] ||
		parity != [inputParity indexValue] ||
		dataBits != [inputDataBits indexValue] ||
		stopBits != [inputStopBits indexValue] &&
		serialDevice > -1)
	{
		// set options here to prevent failures from retrying endlessly
		//NSLog(@"KinemeSerialOutput: Reconfiguring...");
		baudRate = [inputBaudRate indexValue];
		parity = [inputParity indexValue];
		dataBits = [inputDataBits indexValue];
		stopBits = [inputStopBits indexValue];
		
		if(configDevice(serialDevice,baudRate, parity, dataBits, stopBits))
		{
			NSLog(@"KinemeSerialOutput: Error reconfiguring %@",[inputDevice stringValue]);
		}
	}
	if(serialDevice > -1)
	{
		//NSLog(@"KinemeSerialOutput: Have Device...");
		if([inputTrigger booleanValue] && ! oldTrigger)
		{
			int size;
			NSMutableString *sendString = [NSMutableString stringWithString:[inputData stringValue]];
			[sendString replaceOccurrencesOfString:@"\\t" withString:[NSString stringWithFormat:@"%C",NSTabCharacter] options:NSLiteralSearch range:NSMakeRange(0, [sendString length])];
			[sendString replaceOccurrencesOfString:@"\\n" withString:[NSString stringWithFormat:@"%C",NSNewlineCharacter] options:NSLiteralSearch range:NSMakeRange(0, [sendString length])];
			[sendString replaceOccurrencesOfString:@"\\r" withString:[NSString stringWithFormat:@"%C",NSCarriageReturnCharacter] options:NSLiteralSearch range:NSMakeRange(0, [sendString length])];
			//NSLog(@"KinemeSerialOutput: SendString is [%@]",sendString);
			const char *data = [sendString cStringUsingEncoding:NSUTF8StringEncoding];
			//NSLog(@"KinemeSerialOutput: Sending [%s]",data);
			if(data)
				size = write(serialDevice, data, strlen(data));
			else
				NSLog(@"KinemeSerialOutput: NSString conversion failed; not sending data.");
			//NSLog(@"KinemeSerialOutput: Sent %i bytes (of %i)",size, strlen(data));
		}
		if([inputBinaryTrigger booleanValue] && ! oldBinaryTrigger)
		{
			int size, i,j = 0;
			unsigned char *data = malloc(65536);
			NSString *binString = [inputBinaryData stringValue];
			//NSLog(@"KinemeSerialOutput:  Hexifying [%@]",binString);
			// needs to be an even length, so we ignore any odd characters
			for(i=0;i<MIN([binString length]&0xfffe,65536*2); i += 2)
				data[j++] = unhex([binString characterAtIndex:i], [binString characterAtIndex:i+1]);
			
			//NSLog(@"KinemeSerialOutput: Sending Binary data [%02x %02x ...]",data[0],data[1]);
			size = write(serialDevice, data, j);
			free(data);
			//NSLog(@"KinemeSerialOutput: Sent %i bytes (of %i)",size,j);
		}
	}
	oldTrigger = [inputTrigger booleanValue];
	oldBinaryTrigger = [inputBinaryTrigger booleanValue];

	return YES;
}

@end
