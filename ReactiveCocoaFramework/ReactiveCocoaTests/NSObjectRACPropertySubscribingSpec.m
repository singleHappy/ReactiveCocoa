//
//  NSObjectRACPropertySubscribingSpec.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 9/28/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "NSObject+RACPropertySubscribing.h"
#import "RACDisposable.h"
#import "RACTestObject.h"
#import "RACSignal.h"

SpecBegin(NSObjectRACPropertySubscribing)

describe(@"-rac_addDeallocDisposable:", ^{
	it(@"should dispose of the disposable when it is dealloc'd", ^{
		__block BOOL wasDisposed = NO;
		@autoreleasepool {
			NSObject *object __attribute__((objc_precise_lifetime)) = [[NSObject alloc] init];
			[object rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				wasDisposed = YES;
			}]];

			expect(wasDisposed).to.beFalsy();
		}

		expect(wasDisposed).to.beTruthy();
	});
});

describe(@"+rac_signalFor:keyPath:onObject:", ^{
	it(@"should stop observing when disposed", ^{
		RACTestObject *object = [[RACTestObject alloc] init];
		RACSignal *signal = [object.class rac_signalFor:object keyPath:@keypath(object, objectValue) onObject:self];
		NSMutableArray *values = [NSMutableArray array];
		RACDisposable *disposable = [signal subscribeNext:^(id x) {
			[values addObject:x];
		}];

		object.objectValue = @1;
		NSArray *expected = @[ @1 ];
		expect(values).to.equal(expected);

		[disposable dispose];
		object.objectValue = @2;
		expect(values).to.equal(expected);
	});

	it(@"shouldn't keep either object alive unnaturally long", ^{
		__block BOOL objectDealloced = NO;
		__block BOOL scopeObjectDealloced = NO;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[object rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				objectDealloced = YES;
			}]];
			RACTestObject *scopeObject __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			[scopeObject rac_addDeallocDisposable:[RACDisposable disposableWithBlock:^{
				scopeObjectDealloced = YES;
			}]];
			
			RACSignal *signal = [object.class rac_signalFor:object keyPath:@keypath(object, objectValue) onObject:scopeObject];
			[signal subscribeNext:^(id _) {

			}];
		}

		expect(objectDealloced).will.beTruthy();
		expect(scopeObjectDealloced).will.beTruthy();
	});

	it(@"shouldn't crash when the value is changed on a different queue", ^{
		__block id value;
		@autoreleasepool {
			RACTestObject *object __attribute__((objc_precise_lifetime)) = [[RACTestObject alloc] init];
			RACSignal *signal = [NSObject rac_signalFor:object keyPath:@"objectValue" onObject:self];
			[signal subscribeNext:^(id x) {
				value = x;
			}];

			NSOperationQueue *queue = [[NSOperationQueue alloc] init];
			[queue addOperationWithBlock:^{
				object.objectValue = @1;
			}];

			[queue waitUntilAllOperationsAreFinished];
		}

		expect(value).will.equal(@1);
	});
});

SpecEnd
