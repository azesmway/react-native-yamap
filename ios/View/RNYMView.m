#import <React/RCTComponent.h>
#import <React/UIView+React.h>

#import <MapKit/MapKit.h>
@import YandexMapsMobile;

#ifndef MAX
#import <NSObjCRuntime.h>
#endif

#import "YamapPolygonView.h"
#import "YamapPolylineView.h"
#import "YamapMarkerView.h"
#import "YamapCircleView.h"
#import "RNYMView.h"

#define ANDROID_COLOR(c) [UIColor colorWithRed:((c>>16)&0xFF)/255.0 green:((c>>8)&0xFF)/255.0 blue:((c)&0xFF)/255.0  alpha:((c>>24)&0xFF)/255.0]

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@implementation RNYMView {
    YMKMasstransitSession *masstransitSession;
    YMKMasstransitSession *walkSession;
    YMKMasstransitRouter *masstransitRouter;
    YMKDrivingRouter* drivingRouter;
    YMKDrivingSession* drivingSession;
    YMKPedestrianRouter *pedestrianRouter;
    YMKTransitOptions *transitOptions;
    YMKMasstransitSessionRouteHandler routeHandler;
    NSMutableArray<UIView*>* _reactSubviews;
    NSMutableArray *routes;
    NSMutableArray *currentRouteInfo;
    NSMutableArray<YMKRequestPoint *>* lastKnownRoutePoints;
    YMKUserLocationView* userLocationView;
    NSMutableDictionary *vehicleColors;
    UIImage* userLocationImage;
    NSArray *acceptVehicleTypes;
    YMKUserLocationLayer *userLayer;
    UIColor* userLocationAccuracyFillColor;
    UIColor* userLocationAccuracyStrokeColor;
    float userLocationAccuracyStrokeWidth;
    BOOL clusteredMap;
    YMKClusterizedPlacemarkCollection *collection;
    UIImage *buildingsIcon;
    UIImage *monumentsIcon;
    UIImage *museumsIcon;
    UIImage *personalityIcon;
    UIImage *questsIcon;
    UIImage *routesIcon;
    UIImage *territoriesIcon;
    UIColor* clusterColor;
    NSMutableDictionary* placemarks;
}

- (instancetype)init {
    self = [super init];

    _map = [[YMKMapView alloc] initWithFrame:self.bounds];
    _map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    _reactSubviews = [[NSMutableArray alloc] init];
    masstransitRouter = [[YMKTransport sharedInstance] createMasstransitRouter];
    drivingRouter = [[YMKDirections sharedInstance] createDrivingRouter];
    pedestrianRouter = [[YMKTransport sharedInstance] createPedestrianRouter];
    transitOptions = [YMKTransitOptions transitOptionsWithAvoid:YMKFilterVehicleTypesNone timeOptions:[[YMKTimeOptions alloc] init]];
    acceptVehicleTypes = [[NSMutableArray<NSString *> alloc] init];
    routes = [[NSMutableArray alloc] init];
    currentRouteInfo = [[NSMutableArray alloc] init];
    lastKnownRoutePoints = [[NSMutableArray alloc] init];
    vehicleColors = [[NSMutableDictionary alloc] init];
    [vehicleColors setObject:@"#59ACFF" forKey:@"bus"];
    [vehicleColors setObject:@"#7D60BD" forKey:@"minibus"];
    [vehicleColors setObject:@"#F8634F" forKey:@"railway"];
    [vehicleColors setObject:@"#C86DD7" forKey:@"tramway"];
    [vehicleColors setObject:@"#3023AE" forKey:@"suburban"];
    [vehicleColors setObject:@"#BDCCDC" forKey:@"underground"];
    [vehicleColors setObject:@"#55CfDC" forKey:@"trolleybus"];
    [vehicleColors setObject:@"#2d9da8" forKey:@"walk"];
    userLocationAccuracyFillColor = nil;
    userLocationAccuracyStrokeColor = nil;
    userLocationAccuracyStrokeWidth = 0.f;
    [_map.mapWindow.map addCameraListenerWithCameraListener:self];
    [_map.mapWindow.map addInputListenerWithInputListener:(id<YMKMapInputListener>) self];

    buildingsIcon = [UIImage imageNamed:@"assets/images/map/buildings_icon"];
    monumentsIcon = [UIImage imageNamed:@"assets/images/map/monuments_icon"];
    museumsIcon = [UIImage imageNamed:@"assets/images/map/museums_icon"];
    personalityIcon = [UIImage imageNamed:@"assets/images/map/personality_icon"];
    questsIcon = [UIImage imageNamed:@"assets/images/map/quests_icon"];
    routesIcon = [UIImage imageNamed:@"assets/images/map/routes_icon"];
    territoriesIcon = [UIImage imageNamed:@"assets/images/map/territories_icon"];
    collection = [_map.mapWindow.map.mapObjects addClusterizedPlacemarkCollectionWithClusterListener:self];

    clusterColor=nil;
    placemarks = [[NSMutableDictionary alloc] init];

    [self addSubview:_map];

    return self;
}

-(NSDictionary*) convertDrivingRouteSection:(YMKDrivingRoute*) route withSection:(YMKDrivingSection*) section {
    int routeIndex = 0;
    YMKDrivingWeight* routeWeight = route.metadata.weight;
    NSMutableDictionary *routeMetadata = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *routeWeightData = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *sectionWeightData = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *transports = [[NSMutableDictionary alloc] init];
    NSMutableArray *stops = [[NSMutableArray alloc] init];
    [routeWeightData setObject:routeWeight.time.text forKey:@"time"];
    [routeWeightData setObject:routeWeight.timeWithTraffic.text forKey:@"timeWithTraffic"];
    [routeWeightData setObject:@(routeWeight.distance.value) forKey:@"distance"];
    [sectionWeightData setObject:section.metadata.weight.time.text forKey:@"time"];
    [sectionWeightData setObject:section.metadata.weight.timeWithTraffic.text forKey:@"timeWithTraffic"];
    [sectionWeightData setObject:@(section.metadata.weight.distance.value) forKey:@"distance"];
    [routeMetadata setObject:sectionWeightData forKey:@"sectionInfo"];
    [routeMetadata setObject:routeWeightData forKey:@"routeInfo"];
    [routeMetadata setObject:@(routeIndex) forKey:@"routeIndex"];
    [routeMetadata setObject:stops forKey:@"stops"];
    [routeMetadata setObject:UIColor.darkGrayColor forKey:@"sectionColor"];
    if (section.metadata.weight.distance.value == 0) {
        [routeMetadata setObject:@"waiting" forKey:@"type"];
    } else {
        [routeMetadata setObject:@"car" forKey:@"type"];
    }
    NSMutableDictionary *wTransports = [[NSMutableDictionary alloc] init];
    for (NSString *key in transports) {
        [wTransports setObject:[transports valueForKey:key] forKey:key];
    }
    [routeMetadata setObject:wTransports forKey:@"transports"];
    NSMutableArray* points = [[NSMutableArray alloc] init];
    YMKPolyline* subpolyline = YMKMakeSubpolyline(route.geometry, section.geometry);
    for (int i = 0; i < [subpolyline.points count]; ++i) {
        YMKPoint* point = [subpolyline.points objectAtIndex:i];
        NSMutableDictionary* jsonPoint = [[NSMutableDictionary alloc] init];
        [jsonPoint setValue:[NSNumber numberWithDouble:point.latitude] forKey:@"lat"];
        [jsonPoint setValue:[NSNumber numberWithDouble:point.longitude] forKey:@"lon"];
        [points addObject:jsonPoint];
    }
    [routeMetadata setValue:points forKey:@"points"];
    return routeMetadata;
}

-(NSDictionary*) convertRouteSection:(YMKMasstransitRoute*) route withSection:(YMKMasstransitSection*) section {
    int routeIndex = 0;
    YMKMasstransitWeight* routeWeight = route.metadata.weight;
    YMKMasstransitSectionMetadataSectionData *data = section.metadata.data;
    NSMutableDictionary *routeMetadata = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *routeWeightData = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *sectionWeightData = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *transports = [[NSMutableDictionary alloc] init];
    NSMutableArray *stops = [[NSMutableArray alloc] init];
    [routeWeightData setObject:routeWeight.time.text forKey:@"time"];
    [routeWeightData setObject:@(routeWeight.transfersCount) forKey:@"transferCount"];
    [routeWeightData setObject:@(routeWeight.walkingDistance.value) forKey:@"walkingDistance"];
    [sectionWeightData setObject:section.metadata.weight.time.text forKey:@"time"];
    [sectionWeightData setObject:@(section.metadata.weight.transfersCount) forKey:@"transferCount"];
    [sectionWeightData setObject:@(section.metadata.weight.walkingDistance.value) forKey:@"walkingDistance"];
    [routeMetadata setObject:sectionWeightData forKey:@"sectionInfo"];
    [routeMetadata setObject:routeWeightData forKey:@"routeInfo"];
    [routeMetadata setObject:@(routeIndex) forKey:@"routeIndex"];
    for (YMKMasstransitRouteStop *stop in section.stops) {
        [stops addObject:stop.position];
    }
    [routeMetadata setObject:stops forKey:@"stops"];
    if (data.transports != nil) {
        for (YMKMasstransitTransport *transport in data.transports) {
            for (NSString *type in transport.line.vehicleTypes) {
                if ([type isEqual: @"suburban"]) continue;
                if (transports[type] != nil) {
                    NSMutableArray *list = transports[type];
                    if (list != nil) {
                        [list addObject:transport.line.name];
                        [transports setObject:list forKey:type];
                    }
                } else {
                    NSMutableArray *list = [[NSMutableArray alloc] init];
                    [list addObject:transport.line.name];
                    [transports setObject:list forKey:type];
                }
                [routeMetadata setObject:type forKey:@"type"];
                UIColor *color;
                if (transport.line.style != nil) {
                    color = UIColorFromRGB([transport.line.style.color integerValue]);
                } else {
                    if ([vehicleColors valueForKey:type] != nil) {
                        color = [RNYMView colorFromHexString:vehicleColors[type]];
                    } else {
                        color = UIColor.blackColor;
                    }
                }
                [routeMetadata setObject:[RNYMView hexStringFromColor:color] forKey:@"sectionColor"];
            }
        }
    } else {
        [routeMetadata setObject:UIColor.darkGrayColor forKey:@"sectionColor"];
        if (section.metadata.weight.walkingDistance.value == 0) {
            [routeMetadata setObject:@"waiting" forKey:@"type"];
        } else {
            [routeMetadata setObject:@"walk" forKey:@"type"];
        }
    }
    NSMutableDictionary *wTransports = [[NSMutableDictionary alloc] init];
    for (NSString *key in transports) {
        [wTransports setObject:[transports valueForKey:key] forKey:key];
    }
    [routeMetadata setObject:wTransports forKey:@"transports"];
    NSMutableArray* points = [[NSMutableArray alloc] init];
    YMKPolyline* subpolyline = YMKMakeSubpolyline(route.geometry, section.geometry);
    for (int i = 0; i < [subpolyline.points count]; ++i) {
        YMKPoint* point = [subpolyline.points objectAtIndex:i];
        NSMutableDictionary* jsonPoint = [[NSMutableDictionary alloc] init];
        [jsonPoint setValue:[NSNumber numberWithDouble:point.latitude] forKey:@"lat"];
        [jsonPoint setValue:[NSNumber numberWithDouble:point.longitude] forKey:@"lon"];
        [points addObject:jsonPoint];
    }
    [routeMetadata setValue:points forKey:@"points"];
    return routeMetadata;
}

-(void) findRoutes:(NSArray<YMKRequestPoint*>*) _points vehicles:(NSArray<NSString*>*) vehicles withId:(NSString*)_id {
    __weak RNYMView *weakSelf = self;
    if ([vehicles count] == 1 && [[vehicles objectAtIndex:0] isEqualToString:@"car"]) {
        YMKDrivingDrivingOptions* drivingOptions = [[YMKDrivingDrivingOptions alloc] init];
        YMKDrivingVehicleOptions* vehicleOptions = [[YMKDrivingVehicleOptions alloc] init];

        drivingSession = [drivingRouter requestRoutesWithPoints:_points drivingOptions:drivingOptions
                                                 vehicleOptions:vehicleOptions routeHandler:^(NSArray<YMKDrivingRoute *> *routes, NSError *error) {
            RNYMView *strongSelf = weakSelf;
            if (error != nil) {
                [strongSelf onReceiveNativeEvent: @{@"id": _id, @"status": @"error"}];
                return;
            }
            NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
            [response setValue:_id forKey:@"id"];
            [response setValue:@"status" forKey:@"success"];
            NSMutableArray* jsonRoutes = [[NSMutableArray alloc] init];
            for (int i = 0; i < [routes count]; ++i) {
                YMKDrivingRoute* _route = [routes objectAtIndex:i];
                NSMutableDictionary* jsonRoute = [[NSMutableDictionary alloc] init];
                [jsonRoute setValue:[NSString stringWithFormat:@"%d", i] forKey:@"id"];
                NSMutableArray* sections = [[NSMutableArray alloc] init];
                NSArray<YMKDrivingSection *>* _sections = [_route sections];
                for (int j = 0; j < [_sections count]; ++j) {
                    NSDictionary* jsonSection = [self convertDrivingRouteSection:_route withSection: [_sections objectAtIndex:j]];
                    [sections addObject:jsonSection];
                }
                [jsonRoute setValue:sections forKey:@"sections"];
                [jsonRoutes addObject:jsonRoute];
            }
            [response setValue:jsonRoutes forKey:@"routes"];
            [strongSelf onReceiveNativeEvent: response];
        }];
        return;
    }
    YMKMasstransitSessionRouteHandler _routeHandler = ^(NSArray<YMKMasstransitRoute *> *routes, NSError *error) {
        RNYMView *strongSelf = weakSelf;
        if (error != nil) {
            [strongSelf onReceiveNativeEvent: @{@"id": _id, @"status": @"error"}];
            return;
        }
        NSMutableDictionary* response = [[NSMutableDictionary alloc] init];
        [response setValue:_id forKey:@"id"];
        [response setValue:@"status" forKey:@"success"];
        NSMutableArray* jsonRoutes = [[NSMutableArray alloc] init];
        for (int i = 0; i < [routes count]; ++i) {
            YMKMasstransitRoute* _route = [routes objectAtIndex:i];
            NSMutableDictionary* jsonRoute = [[NSMutableDictionary alloc] init];

            [jsonRoute setValue:[NSString stringWithFormat:@"%d", i] forKey:@"id"];
            NSMutableArray* sections = [[NSMutableArray alloc] init];
            NSArray<YMKMasstransitSection *>* _sections = [_route sections];
            for (int j = 0; j < [_sections count]; ++j) {
                NSDictionary* jsonSection = [self convertRouteSection:_route withSection: [_sections objectAtIndex:j]];
                [sections addObject:jsonSection];
            }
            [jsonRoute setValue:sections forKey:@"sections"];
            [jsonRoutes addObject:jsonRoute];
        }
        [response setValue:jsonRoutes forKey:@"routes"];
        [strongSelf onReceiveNativeEvent: response];
    };
    if ([vehicles count] == 0) {
        walkSession = [pedestrianRouter requestRoutesWithPoints:_points timeOptions:[[YMKTimeOptions alloc] init] routeHandler:_routeHandler];
        return;
    }
    YMKTransitOptions* _masstransitOptions = [YMKTransitOptions transitOptionsWithAvoid:YMKFilterVehicleTypesNone timeOptions:[[YMKTimeOptions alloc] init]];
    masstransitSession = [masstransitRouter requestRoutesWithPoints:_points transitOptions:_masstransitOptions routeHandler:_routeHandler];
}

-(UIImage*) resolveUIImage:(NSString*) uri {
    UIImage *icon;
    if ([uri rangeOfString:@"http://"].location == NSNotFound && [uri rangeOfString:@"https://"].location == NSNotFound) {
        if ([uri rangeOfString:@"file://"].location != NSNotFound){
            NSString *file = [uri substringFromIndex:8];
            icon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL fileURLWithPath:file]]];
        } else {
            icon = [UIImage imageNamed:uri];
        }
    } else {
        icon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:uri]]];
    }
    return icon;
}

-(void)onReceiveNativeEvent:(NSDictionary *)response {
    if (self.onRouteFound) self.onRouteFound(response);
}

-(void) removeAllSections {
    [_map.mapWindow.map.mapObjects clear];
}

// REF
- (void)setCenter:(YMKCameraPosition *)position withDuration:(float)duration withAnimation:(int)animation {
    if (duration > 0) {
        YMKAnimationType anim = animation == 0 ? YMKAnimationTypeSmooth : YMKAnimationTypeLinear;
        [_map.mapWindow.map moveWithCameraPosition:position animation:[YMKAnimation animationWithType:anim duration: duration] cameraCallback:^(BOOL completed) {}
        ];
    } else {
        [_map.mapWindow.map moveWithCameraPosition:position];
    }
}

-(void) setZoom:(float) zoom withDuration:(float) duration withAnimation:(int) animation {
    YMKCameraPosition* prevPosition = _map.mapWindow.map.cameraPosition;
    YMKCameraPosition* position = [YMKCameraPosition cameraPositionWithTarget:prevPosition.target zoom:zoom azimuth:prevPosition.azimuth tilt:prevPosition.tilt];
    [self setCenter:position withDuration:duration withAnimation:animation];
}

-(NSDictionary*) cameraPositionToJSON:(YMKCameraPosition*) position finished:(BOOL) finished {
    return @{
        @"azimuth": [NSNumber numberWithFloat:position.azimuth],
        @"tilt": [NSNumber numberWithFloat:position.tilt],
        @"zoom": [NSNumber numberWithFloat:position.zoom],
        @"point": @{
                @"lat": [NSNumber numberWithDouble:position.target.latitude],
                @"lon": [NSNumber numberWithDouble:position.target.longitude],
        },
        @"finished": @(finished)
    };
}

-(NSDictionary*) visibleRegionToJSON:(YMKVisibleRegion*) region {
    return @{
        @"bottomLeft": @{
                @"lat": [NSNumber numberWithDouble:region.bottomLeft.latitude],
                @"lon": [NSNumber numberWithDouble:region.bottomLeft.longitude],
        },
        @"bottomRight": @{
                @"lat": [NSNumber numberWithDouble:region.bottomRight.latitude],
                @"lon": [NSNumber numberWithDouble:region.bottomRight.longitude],
        },
        @"topLeft": @{
                @"lat": [NSNumber numberWithDouble:region.topLeft.latitude],
                @"lon": [NSNumber numberWithDouble:region.topLeft.longitude],
        },
        @"topRight": @{
                @"lat": [NSNumber numberWithDouble:region.topRight.latitude],
                @"lon": [NSNumber numberWithDouble:region.topRight.longitude],
        },
    };
}


-(void) emitCameraPositionToJS:(NSString*) _id {
    YMKCameraPosition* position = _map.mapWindow.map.cameraPosition;
    NSDictionary* cameraPosition = [self cameraPositionToJSON:position finished:YES];
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:cameraPosition];
    [response setValue:_id forKey:@"id"];

    YMKVisibleRegion *visibleRegion = _map.mapWindow.map.visibleRegion;
    double latitudeDelta = visibleRegion.topRight.latitude - visibleRegion.bottomLeft.latitude;
    double longitudeDelta;

    if(visibleRegion.topRight.longitude >= visibleRegion.bottomLeft.longitude) {
        longitudeDelta = visibleRegion.topRight.longitude - visibleRegion.bottomLeft.longitude;
    } else {
        longitudeDelta = visibleRegion.topRight.longitude + 360 - visibleRegion.bottomLeft.longitude;
    }

    NSDictionary *newKey = @{
        @"latitudeDelta": [NSNumber numberWithDouble:latitudeDelta],
        @"longitudeDelta": [NSNumber numberWithDouble:longitudeDelta]
    };
    [response addEntriesFromDictionary:newKey];

    if (self.onCameraPositionReceived) {
        self.onCameraPositionReceived(response);
    }
}

-(void) emitVisibleRegionToJS:(NSString*) _id {
    YMKVisibleRegion* region = _map.mapWindow.map.visibleRegion;
    NSDictionary* visibleRegion = [self visibleRegionToJSON:region];
    NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:visibleRegion];
    [response setValue:_id forKey:@"id"];
    if (self.onVisibleRegionReceived) {
        self.onVisibleRegionReceived(response);
    }
}

-(void) onCameraPositionChangedWithMap:(nonnull YMKMap *)map
                        cameraPosition:(nonnull YMKCameraPosition *)cameraPosition
                    cameraUpdateReason:(YMKCameraUpdateReason)cameraUpdateReason
                              finished:(BOOL)finished {
    YMKVisibleRegion *visibleRegion = map.visibleRegion;
    double latitudeDelta = visibleRegion.topRight.latitude - visibleRegion.bottomLeft.latitude;
    double longitudeDelta;

    if(visibleRegion.topRight.longitude >= visibleRegion.bottomLeft.longitude) {
        longitudeDelta = visibleRegion.topRight.longitude - visibleRegion.bottomLeft.longitude;
    } else {
        longitudeDelta = visibleRegion.topRight.longitude + 360 - visibleRegion.bottomLeft.longitude;
    }

    NSDictionary *newKey = @{
        @"latitudeDelta": [NSNumber numberWithDouble:latitudeDelta],
        @"longitudeDelta": [NSNumber numberWithDouble:longitudeDelta]
    };
    // if (self.onCameraPositionChange) {
    //     self.onCameraPositionChange([self cameraPositionToJSON:cameraPosition finished:finished]);
    // }
    if (self.onCameraPositionChange) {
        NSDictionary *positions = [self cameraPositionToJSON:cameraPosition finished:finished];
        NSMutableDictionary *response = [NSMutableDictionary dictionaryWithDictionary:positions];
        [response addEntriesFromDictionary:newKey];
        self.onCameraPositionChange(response);
    }
}

-(void) setNightMode:(BOOL)nightMode {
    [_map.mapWindow.map setNightModeEnabled:nightMode];
}

- (void)setClusterColor: (UIColor*) color {
    clusterColor = color;
}

- (void)setClusteredMarkers:(NSArray*) markers {
    if (markers.count == 0) {
        return;
    }

    [placemarks removeAllObjects];
    [collection clear];

    YMKIconStyle *icon = [YMKIconStyle new];
    icon.scale = [NSNumber numberWithFloat:1.5f];

    for (NSDictionary *mark in markers) {
        YMKPlacemarkMapObject *placemark;
        NSMutableDictionary* jsonMarker = [[NSMutableDictionary alloc] init];
        double lat = [mark[@"lat"] doubleValue];
        double lon = [mark[@"lon"] doubleValue];
        NSString *slug = [mark[@"slug"] stringValue];
        long id = [mark[@"id"] integerValue];

        if ([slug isEqual:@"houses"]) {
            placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:buildingsIcon style:icon];
        } else if ([slug isEqual:@"museums"]) {
            placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:museumsIcon style:icon];
        } else if ([slug isEqual:@"monuments"]) {
            placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:monumentsIcon style:icon];
        } else if ([slug isEqual:@"quests"]) {
            placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:questsIcon style:icon];
        } else if ([slug isEqual:@"routes"]) {
            placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:routesIcon style:icon];
        } else if ([slug isEqual:@"personalities"]) {
            placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:personalityIcon style:icon];
        } else if ([slug isEqual:@"places"]) {
           placemark = [collection addPlacemarkWithPoint:[YMKPoint pointWithLatitude:lat longitude:lon] image:territoriesIcon style:icon];
       }

        if (placemark != nil) {
            [placemark addTapListenerWithTapListener:self];

            [jsonMarker setValue:[NSNumber numberWithDouble:lat] forKey:@"lat"];
            [jsonMarker setValue:[NSNumber numberWithDouble:lon] forKey:@"lon"];
            [jsonMarker setValue:slug forKey:@"slug"];
            [jsonMarker setValue:[NSNumber numberWithLong:id] forKey:@"id"];

            [placemarks setObject:jsonMarker forKey:[NSString stringWithFormat:@"%lu", (unsigned long)[placemark hash]]];
        }
    }

    [collection clusterPlacemarksWithClusterRadius:60 minZoom:15];
}

-(void) setListenUserLocation:(BOOL)listen {
    YMKMapKit* inst = [YMKMapKit sharedInstance];
    if (userLayer == nil) {
        userLayer = [inst createUserLocationLayerWithMapWindow: _map.mapWindow];
    }
    if (listen) {
        [userLayer setVisibleWithOn:YES];
        [userLayer setObjectListenerWithObjectListener: self];
    } else {
        [userLayer setVisibleWithOn:NO];
        [userLayer setObjectListenerWithObjectListener: nil];
    }
}

- (YMKBoundingBox *)calculateBoundingBox:(NSArray<YMKPoint *> *) points {
    double minLon = [points[0] longitude], maxLon = [points[0] longitude];
    double minLat = [points[0] latitude], maxLat = [points[0] latitude];

    for (int i = 0; i < [points count]; i++) {
        if ([points[i] longitude] > maxLon) maxLon = [points[i] longitude];
        if ([points[i] longitude] < minLon) minLon = [points[i] longitude];
        if ([points[i] latitude] > maxLat) maxLat = [points[i] latitude];
        if ([points[i] latitude] < minLat) minLat = [points[i] latitude];
    }

    YMKPoint *southWest = [YMKPoint pointWithLatitude:minLat longitude:minLon];
    YMKPoint *northEast = [YMKPoint pointWithLatitude:maxLat longitude:maxLon];
    YMKBoundingBox *boundingBox = [YMKBoundingBox boundingBoxWithSouthWest:southWest northEast:northEast];
    return boundingBox;
}

-(void) fitAllMarkers {
    NSMutableArray<YMKPoint *> *lastKnownMarkers = [[NSMutableArray alloc] init];

    for (int i = 0; i < [_reactSubviews count]; ++i) {
        UIView *view = [_reactSubviews objectAtIndex:i];

        if ([view isKindOfClass:[YamapMarkerView class]]) {
            YamapMarkerView *marker = (YamapMarkerView *)view;
            [lastKnownMarkers addObject:[marker getPoint]];
        }
    }

    [self fitMarkers:lastKnownMarkers];
}

- (void)fitMarkers:(NSArray<YMKPoint *> *) points {
    if ([points count] == 1) {
        YMKPoint *center = [points objectAtIndex:0];
        [_map.mapWindow.map moveWithCameraPosition:[YMKCameraPosition cameraPositionWithTarget:center zoom:15 azimuth:0 tilt:0]];
        return;
    }
    YMKCameraPosition *cameraPosition = [_map.mapWindow.map cameraPosition];
    cameraPosition = [YMKCameraPosition cameraPositionWithTarget:cameraPosition.target zoom:cameraPosition.zoom - 0.8f azimuth:cameraPosition.azimuth tilt:cameraPosition.tilt];
    [_map.mapWindow.map moveWithCameraPosition:cameraPosition animation:[YMKAnimation animationWithType:YMKAnimationTypeSmooth duration:1.0] cameraCallback:^(BOOL completed){}];
}

// props
-(void) setUserLocationIcon:(NSString*) iconSource {
    userLocationImage = [self resolveUIImage: iconSource];
    [self updateUserIcon];
}

-(void) setUserLocationAccuracyFillColor: (UIColor*) color {
    userLocationAccuracyFillColor = color;
    [self updateUserIcon];
}

-(void) setUserLocationAccuracyStrokeColor: (UIColor*) color {
    userLocationAccuracyStrokeColor = color;
    [self updateUserIcon];
}

-(void) setUserLocationAccuracyStrokeWidth: (float) width {
    userLocationAccuracyStrokeWidth = width;
    [self updateUserIcon];
}

-(void) updateUserIcon {
    if (userLocationView != nil) {
        if (userLocationImage) {
            [userLocationView.pin setIconWithImage: userLocationImage];
            [userLocationView.arrow setIconWithImage: userLocationImage];
        }
        YMKCircleMapObject* circle = userLocationView.accuracyCircle;
        if (userLocationAccuracyFillColor) {
            [circle setFillColor:userLocationAccuracyFillColor];
        }
        if (userLocationAccuracyStrokeColor) {
            [circle setStrokeColor:userLocationAccuracyStrokeColor];
        }

        [circle setFillColor:[UIColor clearColor]];
        [circle setStrokeWidth:userLocationAccuracyStrokeWidth];
    }
}

// user location listener implementation
- (void)onObjectAddedWithView:(nonnull YMKUserLocationView *)view {
    userLocationView = view;
    [self updateUserIcon];
}

- (void)onObjectRemovedWithView:(nonnull YMKUserLocationView *)view {
}

- (void)onObjectUpdatedWithView:(nonnull YMKUserLocationView *)view event:(nonnull YMKObjectEvent *)event {
    userLocationView = view;
    [self updateUserIcon];
}

- (void)onMapTapWithMap:(nonnull YMKMap *)map
                  point:(nonnull YMKPoint *)point {
    if (self.onMapPress) {
        NSDictionary* data = @{
            @"lat": [NSNumber numberWithDouble:point.latitude],
            @"lon": [NSNumber numberWithDouble:point.longitude],
        };
        self.onMapPress(data);
    }
}

- (void)onMapLongTapWithMap:(nonnull YMKMap *)map
                      point:(nonnull YMKPoint *)point {
    if (self.onMapLongPress) {
        NSDictionary* data = @{
            @"lat": [NSNumber numberWithDouble:point.latitude],
            @"lon": [NSNumber numberWithDouble:point.longitude],
        };
        self.onMapLongPress(data);
    }
}

- (BOOL)onMapObjectTapWithMapObject:(nonnull YMKMapObject *)_mapObject point:(nonnull YMKPoint *)point {
    NSMutableDictionary *jsonMarker = [placemarks valueForKey:[NSString stringWithFormat:@"%lu", (unsigned long)[_mapObject hash]]];

    if (self.onMarkerPress && jsonMarker != nil) {
        NSDictionary* data = @{
            @"lat": [jsonMarker valueForKey:@"lat"],
            @"lon": [jsonMarker valueForKey:@"lon"],
            @"slug": [jsonMarker valueForKey:@"slug"],
            @"id": [jsonMarker valueForKey:@"id"]
        };
        self.onMarkerPress(data);
    }

    return NO;
}

// utils
+(UIColor *) colorFromHexString:(NSString*) hexString {
    unsigned rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner setScanLocation:1];
    [scanner scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16)/255.0 green:((rgbValue & 0xFF00) >> 8)/255.0 blue:(rgbValue & 0xFF)/255.0 alpha:1.0];
}

+(NSString*) hexStringFromColor:(UIColor *) color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255)];
}

// children
-(void)addSubview:(UIView *)view {
    [super addSubview:view];
}

- (void)insertReactSubview:(UIView<RCTComponent>*)subview atIndex:(NSInteger)atIndex {
    if ([subview isKindOfClass:[YamapPolygonView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapPolygonView* polygon = (YamapPolygonView*) subview;
        YMKPolygonMapObject* obj = [objects addPolygonWithPolygon:[polygon getPolygon]];
        [polygon setMapObject:obj];
    } else if ([subview isKindOfClass:[YamapPolylineView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapPolylineView* polyline = (YamapPolylineView*) subview;
        YMKPolylineMapObject* obj = [objects addPolylineWithPolyline:[polyline getPolyline]];
        [polyline setMapObject:obj];
    } else if ([subview isKindOfClass:[YamapMarkerView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapMarkerView* marker = (YamapMarkerView*) subview;
        YMKPlacemarkMapObject* obj = [objects addPlacemarkWithPoint:[marker getPoint]];
        [marker setMapObject:obj];
    } else if ([subview isKindOfClass:[YamapCircleView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapCircleView* circle = (YamapCircleView*) subview;
        YMKCircleMapObject* obj = [objects addCircleWithCircle:[circle getCircle]];
        [circle setMapObject:obj];
    } else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
            [self insertReactSubview:(UIView *)childSubviews[i] atIndex:atIndex];
        }
    }
    [_reactSubviews insertObject:subview atIndex:atIndex];
    [super insertReactSubview:subview atIndex:atIndex];
}

- (void)removeReactSubview:(UIView<RCTComponent>*)subview {
    if ([subview isKindOfClass:[YamapPolygonView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapPolygonView* polygon = (YamapPolygonView*) subview;
        [objects removeWithMapObject:[polygon getMapObject]];
    } else if ([subview isKindOfClass:[YamapPolylineView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapPolylineView* polyline = (YamapPolylineView*) subview;
        [objects removeWithMapObject:[polyline getMapObject]];
    } else if ([subview isKindOfClass:[YamapMarkerView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapMarkerView* marker = (YamapMarkerView*) subview;
        [objects removeWithMapObject:[marker getMapObject]];
    } else if ([subview isKindOfClass:[YamapCircleView class]]) {
        YMKMapObjectCollection *objects = _map.mapWindow.map.mapObjects;
        YamapCircleView* marker = (YamapCircleView*) subview;
        [objects removeWithMapObject:[marker getMapObject]];
    } else {
        NSArray<id<RCTComponent>> *childSubviews = [subview reactSubviews];
        for (int i = 0; i < childSubviews.count; i++) {
            [self removeReactSubview:(UIView *)childSubviews[i]];
        }
    }
    [_reactSubviews removeObject:subview];
    [super removeReactSubview: subview];
}

-(UIImage*)clusterImage:(NSNumber*) clusterSize {
    float FONT_SIZE = 45;
    float MARGIN_SIZE = 9;
    float STROKE_SIZE = 9;
    NSString *text;
    NSInteger s = [clusterSize integerValue];

    if (s > 100) {
        text = [NSString stringWithFormat:@"%i+", 99];
    } else {
        text = [NSString stringWithFormat:@"%ld", (long)s];
    }

    UIFont *font = [UIFont fontWithName:@"Euclid Flex" size:FONT_SIZE];
    CGSize size = [text sizeWithFont:font];
    float textRadius = sqrt(size.height * size.height + size.width * size.width) / 2;
    float internalRadius = textRadius + MARGIN_SIZE;
    float externalRadius = internalRadius + STROKE_SIZE;
    UIImage *someImageView = [UIImage alloc];
    // This function returns a newImage, based on image, that has been:
    // - scaled to fit in (CGRect) rect
    // - and cropped within a circle of radius: rectWidth/2

    //Create the bitmap graphics context
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(externalRadius*2, externalRadius*2), NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [clusterColor CGColor]);
    CGContextFillEllipseInRect(context, CGRectMake(0, 0, externalRadius*2, externalRadius*2));
    CGContextSetFillColorWithColor(context, [clusterColor CGColor]);
    CGContextFillEllipseInRect(context, CGRectMake(STROKE_SIZE, STROKE_SIZE, internalRadius*2, internalRadius*2));
    [text drawInRect:CGRectMake(externalRadius - size.width/2, externalRadius - size.height/2, size.width, size.height) withAttributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.whiteColor }];
       UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
       UIGraphicsEndImageContext();

       return newImage;
}

- (void)onClusterAddedWithCluster:(nonnull YMKCluster *)cluster {
    NSNumber *myNum = @([cluster size]);
    [[cluster appearance] setIconWithImage:[self clusterImage:myNum]];
    [cluster addClusterTapListenerWithClusterTapListener:self];
}

- (void) setClusterMode:(BOOL)clustered {
    clusteredMap = clustered;
}

- (BOOL)onClusterTapWithCluster:(nonnull YMKCluster *)cluster {
    return YES;
}

@synthesize reactTag;

@end
