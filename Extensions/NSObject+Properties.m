/*
 *  NSObject+Properties.m
 *  AQToolkit
 *
 *  Created by Jim Dovey on 10/7/2008.
 *  Copyright (c) 2008 Jim Dovey. Some Rights Reserved.
 *
 *  This work is licensed under a Creative Commons
 *  Attribution-Noncommercial-Share Alike License. You are
 *  free to use and redistribute this work, but may not use
 *  it for commercial purposes, and any changes you make
 *  must be released under the same or similar license.
 *  In addition, you must include the following disclaimer:
 *
 *    Portions Copyright (c) 2008 Jim Dovey
 *
 *  For license details, see:
 *    http://creativecommons.org/licenses/by-nc-sa/3.0/
 *
 */

#import <Foundation/Foundation.h>
#import "NSObject+Properties.h"

static NSDictionary * _AQGetPropertyAttributeDictionary( objc_property_t property );

@implementation NSObject (AQProperties)

+ (BOOL) hasProperties
{
	unsigned int count = 0;
	objc_property_t * properties = class_copyPropertyList( self, &count );
	if ( properties != NULL )
		free( properties );
	
	return ( count != 0 );
}

+ (BOOL) hasPropertyNamed: (NSString *) name
{
	return ( class_getProperty(self, [name UTF8String]) != NULL );
}

+ (BOOL) hasPropertyNamed: (NSString *) name ofType: (const char *) type
{
	objc_property_t property = class_getProperty( self, [name UTF8String] );
	if ( property == NULL )
		return ( NO );

	NSDictionary * attrs = _AQGetPropertyAttributeDictionary( property );
	NSString * value = [attrs objectForKey: @"AQPropertyType"];
	if ( strcmp(type, [value UTF8String]) == 0 )
		return ( YES );
	
	return ( NO );
}

+ (SEL) getterForPropertyNamed: (NSString *) name
{
	objc_property_t property = class_getProperty( self, [name UTF8String] );
	if ( property == NULL )
		return ( NULL );
	
	SEL result = property_getGetter( property );
	if ( result != NULL )
		return ( NULL );
	
	if ( [self instancesRespondToSelector: NSSelectorFromString(name)] == NO )
		[NSException raise: NSInternalInconsistencyException 
					format: @"%@ has property '%@' with no custom getter, but does not respond to the default getter",
		 self, name];
	
	return ( NSSelectorFromString(name) );
}

+ (SEL) setterForPropertyNamed: (NSString *) name
{
	objc_property_t property = class_getProperty( self, [name UTF8String] );
	if ( property == NULL )
		return ( NULL );
	
	SEL result = property_getSetter( property );
	if ( result != NULL )
		return ( result );
	
	// build a setter name
	NSMutableString * str = [NSMutableString stringWithString: @"set"];
	[str appendString: [[name substringToIndex: 1] uppercaseString]];
	if ( [name length] > 1 )
		[str appendString: [name substringFromIndex: 1]];
	
	if ( [self instancesRespondToSelector: NSSelectorFromString(str)] == NO )
		[NSException raise: NSInternalInconsistencyException 
					format: @"%@ has property '%@' with no custom setter, but does not respond to the default setter",
		 self, str];
	
	return ( NSSelectorFromString(str) );
}

+ (NSString *) retentionMethodOfPropertyNamed: (NSString *) name
{
	objc_property_t property = class_getProperty( self, [name UTF8String] );
	if ( property == NULL )
		return ( nil );
	
	const char * str = property_getRetentionMethod( property );
	if ( str == NULL )
		return ( nil );
	
	NSString * result = [NSString stringWithUTF8String: str];
	free( (void *)str );
	
	return ( result );
}

+ (NSArray *) propertyNames
{
	unsigned int i, count = 0;
	objc_property_t properties = class_copyPropertyList( self, &count );
	
	if ( count == 0 )
	{
		free( properties );
		return ( nil );
	}
	
	NSMutableArray * list = [NSMutableArray array];
	
	for ( i = 0; i < count; i++ )
		[list addObject: [NSString stringWithUTF8String: class_getPropertyName(properties[i])]];
	
	return ( [[list copy] autorelease] );
}

- (BOOL) hasProperties
{
	return ( [[self class] hasProperties] );
}

- (BOOL) hasPropertyNamed: (NSString *) name
{
	return ( [[self class] hasPropertyNamed: name] );
}

- (BOOL) hasPropertyNamed: (NSString *) name ofType: (const char *) type
{
	return ( [[self class] hasPropertyNamed: name ofType: type] );
}

- (SEL) getterForPropertyNamed: (NSString *) name
{
	return ( [[self class] getterForPropertyNamed: name] );
}

- (SEL) setterForPropertyNamed: (NSString *) name
{
	return ( [[self class] setterForPropertyNamed: name] );
}

- (NSString *) retentionMethodOfPropertyNamed: (NSString *) name
{
	return ( [[self class] retentionMethodOfPropertyNamed: name] );
}

- (NSArray *) propertyNames
{
	return ( [[self class] propertyNames] );
}

@end

#pragma mark -

SEL property_getGetter( objc_property_t property )
{
	const char * attrs = property_getAttributes( property );
	if ( attrs == NULL )
		return ( NULL );
	
	const char * p = strstr( attrs, ",G" );
	if ( p == NULL )
		return ( NULL );
	
	p += 2;
	const char * e = strchr( p, ',' );
	if ( e == NULL )
		return ( sel_getUid(p) );
	if ( e == p )
		return ( NULL );
	
	int len = (int)(e - p);
	char * selPtr = malloc( len + 1 );
	memcpy( selPtr, p, len );
	selPtr[len] = '\0';
	SEL result = sel_getUid( selPtr );
	free( selPtr );
	
	return ( result );
}

SEL property_getSetter( objc_property_t property )
{
	const char * attrs = property_getAttributes( property );
	if ( attrs == NULL )
		return ( NULL );
	
	const char * p = strstr( attrs, ",S" );
	if ( p == NULL )
		return ( NULL );
	
	p += 2;
	const char * e = strchr( p, ',' );
	if ( e == NULL )
		return ( sel_getUid(p) );
	if ( e == p )
		return ( NULL );
	
	int len = (int)(e - p);
	char * selPtr = malloc( len + 1 );
	memcpy( selPtr, p, len );
	selPtr[len] = '\0';
	SEL result = sel_getUid( selPtr );
	free( selPtr );
	
	return ( result );
}

const char * property_getRetentionMethod( objc_property_t property )
{
	const char * attrs = property_getAttributes( property );
	if ( attrs == NULL )
		return ( NULL );
	
	const char * p = attrs;
	do
	{
		if ( p == NULL )
			break;
		
		if ( p[0] == '\0' )
			break;
		
		if ( p[1] == '&' )
			return ( "retain" );
		
		if ( p[1] == 'C' )
			return ( "copy" );
		
		p = strchr( p, ',' );
		
	} while (1);
	
	// this is the default, and thus has no specifier character in the attr string
	return ( "assign" );
}