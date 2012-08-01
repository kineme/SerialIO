#import "KinemeSerialInput.h"
#import "KinemeSerialIOPatchPrincipal.h"

@implementation KinemeSerialInput : QCPatch

+ (int)executionModeWithIdentifier:(id)fp8
{
	return 2;
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
		[[self userInfo] setObject:@"Kineme Serial Input" forKey:@"name"];

		[inputParity setMaxIndexValue:2];
		[inputParity setIndexValue:2];	// None by default
		[inputDataBits setMaxIndexValue:3];
		[inputDataBits setIndexValue:3];	// 8 data bits by default
		[inputStopBits setMaxIndexValue:1];	// 0 is 1 stop bit by default
		[inputBaudRate setIndexValue:9600];	// a standard default :)
	}
	return self;
}

/*- (void)dealloc
{
	if(serialDevice > -1)
		closeDevice(serialDevice);
	if(recvBuffer)
		free(recvBuffer);
	[super dealloc];
}*/

/*- (BOOL)setup:(QCOpenGLContext *)context
{
	recvBuffer = (char*)calloc(65536,1);
	recvSize = 65536;
	recvIndex = 0;
	serialDevice = -1;
	deviceName = @"";

	return TRUE;
}
- (void)cleanup:(QCOpenGLContext *)context
{
	if(serialDevice > -1)
		closeDevice(serialDevice);
	if(recvBuffer)
		free(recvBuffer);
	//[super cleanup];
}*/


- (void)enable:(QCOpenGLContext *)context
{
	recvBuffer = (char*)calloc(65536,1);
	recvSize = 65536;
	recvIndex = 0;
	serialDevice = -1;
	deviceName = @"";
}

- (void)disable:(QCOpenGLContext *)context
{
	if(serialDevice != -1)
		closeDevice(serialDevice);
	serialDevice = -1;
	if(recvBuffer)
		free(recvBuffer);
}


- (BOOL)execute:(QCOpenGLContext *)context time:(double)time arguments:(NSDictionary *)arguments
{
	// name change.  close/open
	if(	deviceName != [inputDevice stringValue])
	{
		deviceName = [inputDevice stringValue];
		NSLog(@"KinemeSerialInput: Opening %@",[inputDevice stringValue]);
		baudRate = [inputBaudRate indexValue];
		parity = [inputParity indexValue];
		dataBits = [inputDataBits indexValue];
		stopBits = [inputStopBits indexValue];

		if(serialDevice > -1)
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
		NSLog(@"KinemeSerialInput: Reconfiguring...");
		baudRate = [inputBaudRate indexValue];
		parity = [inputParity indexValue];
		dataBits = [inputDataBits indexValue];
		stopBits = [inputStopBits indexValue];
		
		if(configDevice(serialDevice,baudRate, parity, dataBits, stopBits))
		{
			NSLog(@"KinemeSerialInput: Error reconfiguring device");
		}
	}
	
	// if they've asked, clear the buffer.  resets index, so we don't do this every frame
	if([inputClearBuffer booleanValue] && recvIndex != 0)
	{
		//NSLog(@"KinemeSerialInput: clearing buffer");
		recvIndex = 0;
		unsigned int i;
		for(i = 0; i < recvSize; ++i)
			recvBuffer[i] = 0;
		[outputData setStringValue: nil];
	}

	if(serialDevice > -1)
	{
		int size = read(serialDevice, recvBuffer+recvIndex, recvSize-recvIndex);
//		NSLog(@"KinemeSerialInput: read %i bytes from %@",size,[inputDevice stringValue]);
		if(size < 0)
		{
			//NSLog(@"KinemeSerialInput: read error: %s",strerror(errno));
		}
		else
			recvIndex += size;
		if(size+recvIndex == recvSize)	// buffer's full;  make it bigger, up to 1MB
		{
			if(recvSize < 1024*1024)
			{
				recvBuffer = (char*)realloc(recvBuffer,recvSize*2);
				recvSize *= 2;
			}
			else
			{
				NSLog(@"KinemeSerialInput: recvBuffer grew to 1MB... not growing anymore, but dropping characters");
				recvIndex = 0;	// start over... 
			}
		}
	}

	NSMutableString *breakStr = [NSMutableString stringWithString:[inputBreakString stringValue]];
	//NSLog(@"breakStr:  %i: [%@]",[breakStr length],breakStr);
	//[breakStr replaceOccurrencesOfString:@"\\n" withString:[NSString stringWithFormat:@"%C",NSLineSeparatorCharacter] options:NSLiteralSearch range:NSMakeRange(0, [breakStr length])];
	[breakStr replaceOccurrencesOfString:@"\\t" withString:[NSString stringWithFormat:@"%C",NSTabCharacter] options:NSLiteralSearch range:NSMakeRange(0, [breakStr length])];
	[breakStr replaceOccurrencesOfString:@"\\n" withString:[NSString stringWithFormat:@"%C",NSNewlineCharacter] options:NSLiteralSearch range:NSMakeRange(0, [breakStr length])];
	[breakStr replaceOccurrencesOfString:@"\\r" withString:[NSString stringWithFormat:@"%C",NSCarriageReturnCharacter] options:NSLiteralSearch range:NSMakeRange(0, [breakStr length])];

	NSMutableString *outString = [[NSMutableString alloc] initWithCString: recvBuffer];
	if([[inputBreakString stringValue] length] > 0 && serialDevice > -1)
	{
		// if there's a break string, we need to output only the last bit between the break strings.
		NSArray *splitBuffer = [outString componentsSeparatedByString:breakStr];
//		NSLog(@"Splitting [%@] by '%@'(%i) gives us %@",outString,breakStr,[[inputBreakString stringValue] length],splitBuffer);
		// if the string ends with the break, we get a null trailing string, so we avoid that here
		if( [[splitBuffer lastObject] length] == 0 && [splitBuffer count] > 1)
		{
//			NSLog(@"Setting a non-null string output [%@]",
//				[splitBuffer objectAtIndex:[splitBuffer count]-2]);
			[outputData setStringValue: [splitBuffer objectAtIndex:[splitBuffer count]-2]];
			// since we have some output, we nuke the index, and paste in the last object at the head of the list
			unsigned int i;
			for(i=0;i < recvSize; ++i)
				recvBuffer[i] = 0;
			[[splitBuffer lastObject] getCString: recvBuffer maxLength: recvSize encoding: NSASCIIStringEncoding];
			recvIndex =  [[splitBuffer lastObject] length];
		}
		//else
		//{
		//	NSLog(@"Setting Null output (last obj len: %i) (buf count: %i)", [[splitBuffer lastObject] length],
		//		[splitBuffer count]);
		//	[outputData setStringValue: nil];
		//}
		//NSLog(@"Using [%@] as value",[splitBuffer lastObject]);
		//[outputData setStringValue: [splitBuffer lastObject]];
	}
	else	// no separation string, just provide all the data
	{
		[outputData setStringValue: outString];
	}
	[outString release];

	return YES;
}

@end
