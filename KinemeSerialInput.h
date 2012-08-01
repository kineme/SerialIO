#import "QCPatch.h"
#import "QCOpenGLContext.h"

#import "QCBooleanPort.h"
#import "QCStringPort.h"
#import "QCIndexPort.h"

@interface KinemeSerialInput : QCPatch
{
	QCStringPort	*inputDevice;
	QCIndexPort		*inputBaudRate;
	QCIndexPort		*inputParity;
	QCIndexPort		*inputDataBits;
	QCIndexPort		*inputStopBits;
	QCStringPort	*inputBreakString;
	QCBooleanPort	*inputClearBuffer;
	
	QCStringPort	*outputData;
//	QCStringPort	*outputErrorString;
	
	NSString		*deviceName;
	int				serialDevice;
	int				baudRate;
	int				parity;
	int				dataBits;
	int				stopBits;
	char			*recvBuffer;
	unsigned int	recvIndex;
	unsigned int	recvSize;
}

- (id)initWithIdentifier:(id)fp8;

//- (void)cleanup:(QCOpenGLContext *)context;

- (BOOL)execute:(QCOpenGLContext *)context time:(double)time arguments:(NSDictionary *)arguments;
@end
