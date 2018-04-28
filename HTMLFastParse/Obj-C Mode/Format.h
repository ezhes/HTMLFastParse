//
//  Format.h
//  HTMLFastParse
//
//  Created by Salman Husain on 4/27/18.
//  Copyright © 2018 CarbonDev. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Format : NSObject {
	@public int stackIndex;
	@public int endIndex;
	@public NSMutableString *tag;
}
@end
