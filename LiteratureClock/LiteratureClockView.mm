//
//  LiteratureClockView.m
//  LiteratureClock
//
//  Created by Sash Zats on 8/25/18.
//  Copyright © 2018 Sash Zats. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <vector>

#import "LiteratureClockView.h"

static NSAttributedString *attributedStringForQuote(NSString *quote, NSString *highlight, NSString *title, NSString *author)
{
  const auto highlightRange = [quote rangeOfString:highlight options:NSCaseInsensitiveSearch];
  const auto defaultAttrbitutes = @{
                               NSForegroundColorAttributeName: NSColor.darkGrayColor,
                               NSFontAttributeName: [NSFont fontWithName:@"Times" size:50],
                               };
  const auto attributionAttrbitutes = @{
                                    NSForegroundColorAttributeName: NSColor.darkGrayColor,
                                    NSParagraphStyleAttributeName: ({
                                      const auto paragraph = [NSMutableParagraphStyle new];
                                      paragraph.alignment = NSTextAlignmentRight;
                                      paragraph;
                                    }),
                                    NSFontAttributeName: [NSFont fontWithName:@"Times" size:20],
                                    };
  const auto highlightedAttributes = @{
                                  NSForegroundColorAttributeName: NSColor.lightGrayColor,
                                  NSFontAttributeName: [NSFont fontWithName:@"Times" size:50],
                                  };
  NSMutableAttributedString *const result = [[NSMutableAttributedString alloc]
                                             initWithString:quote
                                             attributes:defaultAttrbitutes];

  [result addAttributes:highlightedAttributes range:highlightRange];
  [result appendAttributedString:
   [[NSAttributedString alloc]
    initWithString:[NSString stringWithFormat:@"\n\n\n\n– %@, %@", title, author]
    attributes:attributionAttrbitutes]];

  return result;
}

@implementation LiteratureClockView
{
  NSDateFormatter *_formatter;
  NSDictionary<NSString *, NSArray<NSAttributedString *> *> *_quotes;

  NSDateComponents *_lastComponents;
  NSAttributedString *_lastQuote;
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
      [self parseQuotes];
      self.animationTimeInterval = 1;

      _formatter = [NSDateFormatter new];
      _formatter.dateFormat = @"HH:mm";
      _formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
      _formatter.timeZone = [NSTimeZone localTimeZone];
    }
    return self;
}

- (void)parseQuotes
{
  NSMutableDictionary<NSString *, NSMutableArray<NSAttributedString *> *> *const quotes = [NSMutableDictionary new];

  const auto url = [[NSBundle bundleForClass:self.class] URLForResource:@"data" withExtension:@"csv"];
  const auto rawText = [[NSString
                         stringWithContentsOfURL:url
                         encoding:NSUTF8StringEncoding
                         error:nil]
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  for (NSString *const row in [rawText componentsSeparatedByString:@"\n"]) {
    const auto columns = [row componentsSeparatedByString:@"|"];
    const auto time = [columns[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    const auto quote = [columns[2] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    const auto highlight = [columns[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    const auto title = [columns[3] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    const auto author = [columns[4] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    // lazy set creation
    if (!quotes[time]) {
      quotes[time] = [NSMutableArray new];
    }
    //
    [quotes[time] addObject:attributedStringForQuote(quote,
                                                     highlight,
                                                     title,
                                                     author)];
  }
  _quotes = quotes;
}

- (void)startAnimation
{
    [super startAnimation];
}

- (void)stopAnimation
{
    [super stopAnimation];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect:rect];

  const auto context = NSGraphicsContext.currentContext.CGContext;
  [[NSColor blackColor] setFill];
  CGContextFillRect(context, self.bounds);


  const auto calendar = [NSCalendar currentCalendar];
  const auto date = [NSDate date];

  const auto components = [calendar components:NSCalendarUnitHour|NSCalendarUnitMinute fromDate:date];
  if ([_lastComponents isEqualTo:components]) {
    [self drawQuote:_lastQuote];
    return;
  }

  _lastQuote = nil;
  _lastComponents = components;
  // 5 minutes earlier
  std::vector<int> deltas = { 0, -1, 1, 2, -2, 3, -3 };
  for (int i = 0; i < deltas.size(); ++i) {
    const auto newDate = [calendar dateByAddingUnit:NSCalendarUnitMinute value:deltas[i] toDate:date options:0];
    const auto quote = [self quoteForDate:newDate];
    if (quote) {
      _lastQuote = quote;
      [self drawQuote:quote];
      return;
    }
  }
  _lastQuote = nil;
  [self drawQuote:nil];
}

- (void)drawQuote:(NSAttributedString *)quote
{
  if (!quote) {
    quote = [[NSAttributedString alloc] initWithString:@"shrug"];
  }

  CGFloat maxWidth = CGRectGetWidth(self.bounds) * 0.5;
  auto size = (CGSize){ 0, FLT_MAX }; // set up initial value to enter the loop

  while ((size.height > size.width
          || size.height > CGRectGetHeight(self.bounds) * 0.8)
         && maxWidth < CGRectGetWidth(self.bounds) * 0.9) {
    size =
    [quote
     boundingRectWithSize:(NSSize){
       maxWidth,
       CGFLOAT_MAX,
     }
     options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading].size;
    maxWidth += CGRectGetWidth(self.bounds) * 0.05;
  }
  const auto rect = (CGRect){
    (CGRectGetWidth(self.bounds) - size.width) * 0.5,
    (CGRectGetHeight(self.bounds) - size.height) * 0.5,
    size.width,
    size.height,
  };
  [quote drawInRect:rect];
}

- (NSAttributedString *_Nullable)quoteForDate:(NSDate *)date
{
  const auto time = [_formatter stringFromDate:date];
  NSLog(@"looking for %@", time);
  const auto quotes = _quotes[time];
  return quotes[(int)arc4random_uniform((int)quotes.count)];
}

- (void)animateOneFrame
{
  [self setNeedsDisplay:YES];
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow*)configureSheet
{
    return nil;
}

@end
