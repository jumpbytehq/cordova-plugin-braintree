//
//  BraintreePlugin.m
//
//  Copyright (c) 2016 Justin Unterreiner. All rights reserved.
//

#import "BraintreePlugin.h"
#import <objc/runtime.h>
#import <BraintreeUI/BTDropInViewController.h>
#import <BraintreeCore/BTAPIClient.h>
#import <BraintreeCore/BTPaymentMethodNonce.h>
#import <BraintreeCard/BTCardNonce.h>
#import <BraintreePayPal/BraintreePayPal.h>
#import <BraintreeApplePay/BraintreeApplePay.h>
#import <Braintree3DSecure/Braintree3DSecure.h>
#import <BraintreeVenmo/BraintreeVenmo.h>

@interface BraintreePlugin() <BTDropInViewControllerDelegate>

@property (nonatomic, strong) BTAPIClient *braintreeClient;

@end

@implementation BraintreePlugin

NSString *dropInUIcallbackId;

#pragma mark - Cordova commands

- (void)initialize:(CDVInvokedUrlCommand *)command {

    // Ensure we have the correct number of arguments.
    if ([command.arguments count] != 1) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Obtain the arguments.
    NSString* token = [command.arguments objectAtIndex:0];

    if (!token) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"A token is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    self.braintreeClient = [[BTAPIClient alloc] initWithAuthorization:token];

    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client failed to initialize."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }
    // Obtain the arguments.
    
    NSString* cancelText = @"Cancel";//[command.arguments objectAtIndex:0];
    NSString* title = @"EZER";//[command.arguments objectAtIndex:1];
    
    //CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    //[self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
    // Save off the Cordova callback ID so it can be used in the completion handlers.
    dropInUIcallbackId = command.callbackId;
    
    // Create a BTDropInViewController
    BTDropInViewController *dropInViewController = [[BTDropInViewController alloc]
                                                    initWithAPIClient:self.braintreeClient];
    dropInViewController.delegate = self;
    
    // Setup the cancel button.
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]
                                     initWithTitle:cancelText
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(userDidCancelPayment)];
    
    dropInViewController.navigationItem.leftBarButtonItem = cancelButton;
    
    // Setup the dialog's title.
    dropInViewController.title = title;
    
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:dropInViewController];
    
    [self.viewController presentViewController:navigationController animated:YES completion:nil];

}

- (void)presentDropInPaymentUI:(CDVInvokedUrlCommand *)command {

    // Ensure the client has been initialized.
    if (!self.braintreeClient) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"The Braintree client must first be initialized via BraintreePlugin.initialize(token)"];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Ensure we have the correct number of arguments.
    if ([command.arguments count] != 2) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"cancelText and title are required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Obtain the arguments.

    NSString* cancelText = [command.arguments objectAtIndex:0];

    if (!cancelText) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"cancelText is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    NSString* title = [command.arguments objectAtIndex:1];

    if (!title) {
        CDVPluginResult *res = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"title is required."];
        [self.commandDelegate sendPluginResult:res callbackId:command.callbackId];
        return;
    }

    // Save off the Cordova callback ID so it can be used in the completion handlers.
    dropInUIcallbackId = command.callbackId;

    // Create a BTDropInViewController
    BTDropInViewController *dropInViewController = [[BTDropInViewController alloc]
                                                    initWithAPIClient:self.braintreeClient];
    dropInViewController.delegate = self;

    // Setup the cancel button.

    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc]
                                     initWithTitle:cancelText
                                     style:UIBarButtonItemStylePlain
                                     target:self
                                     action:@selector(userDidCancelPayment)];

    dropInViewController.navigationItem.leftBarButtonItem = cancelButton;

    // Setup the dialog's title.
    dropInViewController.title = title;

    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:dropInViewController];

    [self.viewController presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - Event Handlers

- (void)userDidCancelPayment {

    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"dropInViewController userDidCancelPayment fired" );
    if (dropInUIcallbackId) {

        NSDictionary *dictionary = @{ @"userCancelled": @YES };

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:dictionary];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
        dropInUIcallbackId = nil;
    }
}

#pragma mark - BTDropInViewControllerDelegate Members

- (void)dropInViewController:(BTDropInViewController *)viewController
  didSucceedWithTokenization:(BTPaymentMethodNonce *)paymentMethodNonce {
    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"dropInViewController didSucceedWithTokenization fired" );
    
    if (dropInUIcallbackId) {
        NSDictionary *dictionary = [self getPaymentUINonceResult:paymentMethodNonce];
        NSLog(@"dropInViewController didSucceedWithTokenization paymentMethodNonce%@", dictionary);

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:dictionary];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
        dropInUIcallbackId = nil;
    }
}

- (void)dropInViewControllerDidCancel:(__unused BTDropInViewController *)viewController {

    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"dropInViewController dropInViewControllerDidCancel fired" );

    if (dropInUIcallbackId) {

        NSDictionary *dictionary = @{ @"userCancelled": @YES };

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                      messageAsDictionary:dictionary];

        [self.commandDelegate sendPluginResult:pluginResult callbackId:dropInUIcallbackId];
        dropInUIcallbackId = nil;
    }
}

#pragma mark - Helpers

/**
 * Helper used to return a dictionary of values from the given payment method nonce.
 * Handles several different types of nonces (eg for cards, Apple Pay, PayPal, etc).
 */
- (NSDictionary*)getPaymentUINonceResult:(BTPaymentMethodNonce *)paymentMethodNonce {
    BTCardNonce *cardNonce;
    BTPayPalAccountNonce *payPalAccountNonce;
    BTApplePayCardNonce *applePayCardNonce;
    BTThreeDSecureCardNonce *threeDSecureCardNonce;
    BTVenmoAccountNonce *venmoAccountNonce;
    
    if ([paymentMethodNonce isKindOfClass:[BTCardNonce class]]) {
        NSLog(@"dropInViewController cardNonce fired");

        cardNonce = (BTCardNonce*)paymentMethodNonce;
    }

    if ([paymentMethodNonce isKindOfClass:[BTPayPalAccountNonce class]]) {
        NSLog(@"dropInViewController payPalAccountNonce fired");
        payPalAccountNonce = (BTPayPalAccountNonce*)paymentMethodNonce;
    }

    if ([paymentMethodNonce isKindOfClass:[BTApplePayCardNonce class]]) {
        NSLog(@"dropInViewController applePayCardNonce fired");
        applePayCardNonce = (BTApplePayCardNonce*)paymentMethodNonce;
    }

    if ([paymentMethodNonce isKindOfClass:[BTThreeDSecureCardNonce class]]) {
        NSLog(@"dropInViewController threeDSecureCardNonce fired");
        threeDSecureCardNonce = (BTThreeDSecureCardNonce*)paymentMethodNonce;
    }

    if ([paymentMethodNonce isKindOfClass:[BTVenmoAccountNonce class]]) {
        NSLog(@"dropInViewController venmoAccountNonce fired");
        venmoAccountNonce = (BTVenmoAccountNonce*)paymentMethodNonce;
    }
    
    NSDictionary *dictionary = @{ @"userCancelled": @NO,

                                  // Standard Fields
                                  @"nonce": paymentMethodNonce.nonce,
                                  @"type": paymentMethodNonce.type,
                                  @"localizedDescription": paymentMethodNonce.localizedDescription,

                                  // BTCardNonce Fields
                                  @"card": !cardNonce ? [NSNull null] : @{
                                          @"lastTwo": cardNonce.lastTwo,
                                          @"network": [self formatCardNetwork:cardNonce.cardNetwork]
                                          },

                                  // BTPayPalAccountNonce
                                  @"payPalAccount": !payPalAccountNonce ? [NSNull null] : @{
                                          @"email": payPalAccountNonce.email,
                                          @"firstName": payPalAccountNonce.firstName,
                                          @"lastName": payPalAccountNonce.lastName,
                                          @"phone": !payPalAccountNonce.phone ? [NSNull null] : payPalAccountNonce.phone,
                                          //@"billingAddress" //TODO
                                          //@"shippingAddress" //TODO
                                          @"clientMetadataId": !payPalAccountNonce.clientMetadataId ? [NSNull null] : payPalAccountNonce.clientMetadataId,
                                          @"payerId": !payPalAccountNonce.payerId ? [NSNull null] : payPalAccountNonce.payerId
                                          },

                                  // BTApplePayCardNonce
                                  @"applePayCard": !applePayCardNonce ? [NSNull null] : @{
                                          },

                                  // BTThreeDSecureCardNonce Fields
                                  @"threeDSecureCard": !threeDSecureCardNonce ? [NSNull null] : @{
                                          @"liabilityShifted": threeDSecureCardNonce.liabilityShifted ? @YES : @NO,
                                          @"liabilityShiftPossible": threeDSecureCardNonce.liabilityShiftPossible ? @YES : @NO
                                          },

                                  // BTVenmoAccountNonce Fields
                                  @"venmoAccount": !venmoAccountNonce ? [NSNull null] : @{
                                          @"username": venmoAccountNonce.username
                                          }
                                  };
    return dictionary;
}

/**
 * Helper used to provide a string value for the given BTCardNetwork enumeration value.
 */
- (NSString*)formatCardNetwork:(BTCardNetwork)cardNetwork {
    NSString *result = nil;

    // TODO: This method should probably return the same values as the Android plugin for consistency.

    switch (cardNetwork) {
        case BTCardNetworkUnknown:
            result = @"BTCardNetworkUnknown";
            break;
        case BTCardNetworkAMEX:
            result = @"BTCardNetworkAMEX";
            break;
        case BTCardNetworkDinersClub:
            result = @"BTCardNetworkDinersClub";
            break;
        case BTCardNetworkDiscover:
            result = @"BTCardNetworkDiscover";
            break;
        case BTCardNetworkMasterCard:
            result = @"BTCardNetworkMasterCard";
            break;
        case BTCardNetworkVisa:
            result = @"BTCardNetworkVisa";
            break;
        case BTCardNetworkJCB:
            result = @"BTCardNetworkJCB";
            break;
        case BTCardNetworkLaser:
            result = @"BTCardNetworkLaser";
            break;
        case BTCardNetworkMaestro:
            result = @"BTCardNetworkMaestro";
            break;
        case BTCardNetworkUnionPay:
            result = @"BTCardNetworkUnionPay";
            break;
        case BTCardNetworkSolo:
            result = @"BTCardNetworkSolo";
            break;
        case BTCardNetworkSwitch:
            result = @"BTCardNetworkSwitch";
            break;
        case BTCardNetworkUKMaestro:
            result = @"BTCardNetworkUKMaestro";
            break;
        default:
            result = nil;
    }

    return result;
}

@end
