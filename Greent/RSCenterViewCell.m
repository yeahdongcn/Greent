//
//  RSCenterViewCell.m
//  Greent
//
//  Created by R0CKSTAR on 8/26/13.
//  Copyright (c) 2013 P.D.Q. All rights reserved.
//

#import "RSCenterViewCell.h"

@interface RSCenterViewCell ()

@property (nonatomic, weak) IBOutlet UIView *border;

@end

@implementation RSCenterViewCell

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self addObserver:self forKeyPath:@"border" options:NSKeyValueObservingOptionNew context:NULL];
    }
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"border"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"border"]) {
        self.border.backgroundColor = [UIColor whiteColor];
        
        self.border.layer.borderColor = [UIColor redColor].CGColor;
        self.border.layer.borderWidth = 2;
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
