//
//  GrapheneSerializer.m
//
//  Created by SYALON on 13-9-3.
//
//

#import "GrapheneSerializer.h"
#import "BinSerializer.h"
#import "OrgUtils.h"
#import "Extension.h"
#import "bts_chain_config.h"

//#import "objc/message.h"
//#import "objc/objc-api.h"
//#import "objc/objc.h"
#import "objc/runtime.h"

static const char* __bitshares_type_fields__ = "__bitshares_type_fields__";

@interface T_Base()
{
    id  _opdata;
}
@end

@implementation T_Base

+ (NSData*)encode_to_bytes:(id)opdata
{
    BinSerializer* io = [[BinSerializer alloc] init];
    [self encode_to_bytes_with_type:self opdata:opdata io:io];
    return [io getData];
}

+ (id)encode_to_object:(id)opdata
{
    return [self encode_to_object_with_type:self opdata:opdata];
}

+ (void)encode_to_bytes_with_type:(id)optype opdata:(id)opdata io:(BinSerializer*)io
{
    [optype performSelector:@selector(to_byte_buffer:opdata:) withObject:io withObject:opdata];
}

+ (id)encode_to_object_with_type:(id)optype opdata:(id)opdata
{
    return [optype performSelector:@selector(to_object:) withObject:opdata];
}

+ (void)add_field:(NSString*)name class:(id)klass
{
    assert(name);
    assert(klass);
    id fields = [self get_fields:YES];
    assert(fields);
    [fields addObject:@[name, klass]];
}

+ (NSMutableArray*)get_fields:(BOOL)init_on_nil
{
    NSMutableArray* fields = objc_getAssociatedObject(self, __bitshares_type_fields__);
    if (!fields && init_on_nil){
        fields = [NSMutableArray array];
        objc_setAssociatedObject(self, __bitshares_type_fields__, fields, OBJC_ASSOCIATION_RETAIN);
    }
    return fields;
}

/**
 *  (public) 注册可序列化的类型。REMARK：所有复合类型都必须注册，基本类型不用注册。
 */
+ (void)registerAllType
{
    [T_asset performSelector:@selector(register_subfields)];
    [T_memo_data performSelector:@selector(register_subfields)];
    
    [T_transfer performSelector:@selector(register_subfields)];
    [T_limit_order_create performSelector:@selector(register_subfields)];
    [T_limit_order_cancel performSelector:@selector(register_subfields)];
    [T_call_order_update performSelector:@selector(register_subfields)];
    [T_authority performSelector:@selector(register_subfields)];
    [T_account_options performSelector:@selector(register_subfields)];
    [T_account_create performSelector:@selector(register_subfields)];
    [T_account_update performSelector:@selector(register_subfields)];
    [T_account_upgrade performSelector:@selector(register_subfields)];
    
    [T_linear_vesting_policy_initializer performSelector:@selector(register_subfields)];
    [T_cdd_vesting_policy_initializer performSelector:@selector(register_subfields)];
    [T_vesting_balance_create performSelector:@selector(register_subfields)];
    [T_vesting_balance_withdraw performSelector:@selector(register_subfields)];
    
    [T_op_wrapper performSelector:@selector(register_subfields)];
    [T_proposal_create performSelector:@selector(register_subfields)];
    [T_proposal_update performSelector:@selector(register_subfields)];
    [T_proposal_delete performSelector:@selector(register_subfields)];
    
    [T_price performSelector:@selector(register_subfields)];
    [T_asset_options performSelector:@selector(register_subfields)];
    [T_bitasset_options performSelector:@selector(register_subfields)];
    [T_asset_create performSelector:@selector(register_subfields)];
    [T_asset_settle performSelector:@selector(register_subfields)];
    [T_asset_update performSelector:@selector(register_subfields)];
    [T_asset_update_bitasset performSelector:@selector(register_subfields)];
    [T_asset_update_feed_producers performSelector:@selector(register_subfields)];
    [T_asset_reserve performSelector:@selector(register_subfields)];
    [T_asset_issue performSelector:@selector(register_subfields)];
    [T_asset_claim_pool performSelector:@selector(register_subfields)];
    [T_asset_update_issuer performSelector:@selector(register_subfields)];
    
    [T_htlc_create performSelector:@selector(register_subfields)];
    [T_htlc_redeem performSelector:@selector(register_subfields)];
    [T_htlc_extend performSelector:@selector(register_subfields)];
    
    [T_transaction performSelector:@selector(register_subfields)];
    [T_signed_transaction performSelector:@selector(register_subfields)];
}

+ (void)register_subfields
{
    //  ...
}

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    id fields = [self get_fields:NO];
    assert(fields && [fields count] > 0);
    for (id field in fields) {
        id field_name = [field firstObject];
        id field_type = [field lastObject];
        id value = [opdata objectForKey:field_name];
        [self encode_to_bytes_with_type:field_type opdata:value io:io];
    }
}

+ (id)to_object:(id)opdata
{
    assert(opdata);
    id fields = [self get_fields:NO];
    if (fields && [fields count] > 0){
        NSMutableDictionary* result = [NSMutableDictionary dictionary];
        for (id field in fields) {
            id field_name = [field firstObject];
            id field_type = [field lastObject];
            id value = [opdata objectForKey:field_name];
            id obj = [self encode_to_object_with_type:field_type opdata:value];
            if (obj){
                [result setObject:obj forKey:field_name];
            }else{
                assert([field_type isKindOfClass:[Tm_optional class]]);
            }
        }
        return [result copy];
    }else{
        return opdata;
    }
}

/*
 *  排序：部分类型序列化需要排序。
 *  各种类型可以通过实现：sort_by 方法自定义排序。
 */
+ (NSArray*)sort_opdata_array:(NSArray*)array optype:(id)sort_by_optype
{
    //  no need to sort
    if (!array || [array count] <= 1) {
        return array;
    }
    
    //  no sort
    if ([sort_by_optype respondsToSelector:@selector(nosort)] && [[sort_by_optype performSelector:@selector(nosort)] boolValue]) {
        return array;
    }
    
    //  sort using custom compare func
    SEL sel = @selector(sort_by:b:);
    if ([sort_by_optype respondsToSelector:sel]) {
        NSMethodSignature* signature = [sort_by_optype methodSignatureForSelector:sel];
        NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:sort_by_optype];
        [invocation setSelector:sel];
        return [array sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            id a = [obj1 isKindOfClass:[NSArray class]] ? [obj1 objectAtIndex:0] : obj1;
            id b = [obj2 isKindOfClass:[NSArray class]] ? [obj2 objectAtIndex:0] : obj2;
            [invocation setArgument:&a atIndex:2];
            [invocation setArgument:&b atIndex:3];
            [invocation invoke];
            NSInteger retv = 0;
            [invocation getReturnValue:&retv];
            return retv;
        }];
    }
    
    //  sort use default compare func
    return [array sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        id a = [obj1 isKindOfClass:[NSArray class]] ? [obj1 objectAtIndex:0] : obj1;
        id b = [obj2 isKindOfClass:[NSArray class]] ? [obj2 objectAtIndex:0] : obj2;
        if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]]) {
            return [a integerValue] - [b integerValue];
        } else if ([a isKindOfClass:[NSData class]] && [b isKindOfClass:[NSData class]]){
            return [[a hex_encode] compare:[b hex_encode]];
        } else {
            return [a compare:b];
        }
    }];
}

@end

#pragma mark- 以下为基本数据类型。

@implementation T_uint8

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [io write_u8:(uint8_t)[opdata unsignedIntValue]];
}

@end

@implementation T_uint16

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [io write_u16:(uint16_t)[opdata intValue]];
}

@end

@implementation T_uint32

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [io write_u32:(uint32_t)[opdata unsignedLongValue]];
}

@end

@implementation T_uint64

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [io write_u64:(uint64_t)[opdata unsignedLongLongValue]];
}

@end

@implementation T_int64

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [io write_s64:(int64_t)[opdata longLongValue]];
}

@end

@implementation T_varint32

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [io write_varint32:(uint64_t)[opdata unsignedLongLongValue]];
}

@end

@implementation T_string

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert([opdata isKindOfClass:[NSString class]]);
    [io write_string:opdata];
}

@end

@implementation T_bool

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    if ([opdata boolValue]){
        [io write_u8:1];
    }else{
        [io write_u8:0];
    }
}

@end

@implementation T_void

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    NSAssert(false, @"(void) undefined type");
}

@end

@implementation T_future_extensions
@end

@implementation T_object_id_type

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    //  TODO:fowallet not supported
    NSAssert(false, @"not supported");
}

@end

@implementation T_vote_id

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    //  TODO: fowallet voite id有效性验证。
    assert([opdata isKindOfClass:[NSString class]]);
    //  v.require_test(/^[0-9]+:[0-9]+$/, object, `vote_id format ${object}`);
    id ary = [opdata componentsSeparatedByString:@":"];
    assert([ary count] == 2);
    uint32_t vote_type = (uint32_t)[ary[0] integerValue];
    uint32_t vote_idnum = (uint32_t)[ary[1] integerValue];;
    //  v.require_range(0, 0xff, type, `vote type ${object}`);
    //  v.require_range(0, 0xffffff, id, `vote id ${object}`);
    [io write_u32:(uint32_t)((vote_idnum << 8) | vote_type)];
}

+ (NSInteger)sort_by:(id)a b:(id)b
{
    id ary1 = [a componentsSeparatedByString:@":"];
    id ary2 = [b componentsSeparatedByString:@":"];
    return [[ary1 lastObject] integerValue] - [[ary2 lastObject] integerValue];
}

@end

@implementation T_public_key

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert([opdata isKindOfClass:[NSString class]]);
    [io write_public_key:opdata];
}

+ (NSInteger)sort_by:(id)a b:(id)b
{
    //  参考：fc::array<char,33>
    NSData* da = [OrgUtils genBtsBlockchainAddress:a];
    NSData* db = [OrgUtils genBtsBlockchainAddress:b];
    assert(da && db && da.length == db.length);
    return (NSInteger)memcmp(da.bytes, db.bytes, da.length);
}

@end

@implementation T_address

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    //  TODO:fowallet not supported
    NSAssert(false, @"not supported");
}

@end

@implementation T_time_point_sec

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    [super to_byte_buffer:io opdata:opdata];
}

+ (id)to_object:(id)opdata
{
    //  格式：2018-06-04T13:03:57
    return [OrgUtils formatBitsharesTimeString:(NSTimeInterval)[opdata unsignedLongValue]];
}

@end

#pragma mark- 以下为动态扩展类型。

@implementation Tm_protocol_id_type

- (id)initWithName:(NSString*)name
{
    self = [super init];
    if (self)
    {
        //  TODO:save name
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    //  TODO:check name 和 object_id 类型是否匹配 待处理
    [io write_object_id:opdata];
}

- (id)to_object:(id)opdata
{
    return opdata;
}

- (NSInteger)sort_by:(id)a b:(id)b
{
    NSInteger ia = [[[a componentsSeparatedByString:@"."] lastObject] integerValue];
    NSInteger ib = [[[b componentsSeparatedByString:@"."] lastObject] integerValue];
    return ia - ib;
}

@end

@interface Tm_extension()
{
    NSArray*    _fields_def;
    
}
@end

@implementation Tm_extension

- (id)initWithFieldsDef:(NSArray*)fields_def
{
    self = [super init];
    if (self)
    {
        _fields_def = fields_def;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    //  统计出现的扩展字段数量
    uint32_t field_count = 0;
    if (_fields_def && opdata){
        for (id fields in _fields_def) {
            id field_name = [fields objectForKey:@"name"];
            assert(field_name);
            if ([opdata objectForKey:field_name]){
                ++field_count;
            }
        }
    }
    //  写入扩展字段数量
    [io write_varint32:field_count];
    //  写入扩展字段的值
    if (field_count > 0){
        uint32_t idx = 0;
        for (id fields in _fields_def) {
            id obj = [opdata objectForKey:[fields objectForKey:@"name"]];
            if (obj){
                [io write_varint32:idx];
                [[self class] encode_to_bytes_with_type:[fields objectForKey:@"type"] opdata:obj io:io];
            }
            ++idx;
        }
    }
}

- (id)to_object:(id)opdata
{
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    if (_fields_def && opdata){
        for (id fields in _fields_def) {
            id field_name = [fields objectForKey:@"name"];
            assert(field_name);
            id obj = [opdata objectForKey:field_name];
            if (obj){
                [result setObject:[[self class] encode_to_object_with_type:[fields objectForKey:@"type"] opdata:obj] forKey:field_name];
            }
        }
    }
    return [result copy];
}

@end

@interface Tm_array()
{
    id  _optype;
}
@end

@implementation Tm_array

- (id)initWithType:(id)optype
{
    self = [super init];
    if (self)
    {
        _optype = optype;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert([opdata isKindOfClass:[NSArray class]]);
    [io write_varint32:(uint64_t)[opdata count]];
    for (id sub_opdata in opdata) {
        [[self class] encode_to_bytes_with_type:_optype opdata:sub_opdata io:io];
    }
}

- (id)to_object:(id)opdata
{
    assert([opdata isKindOfClass:[NSArray class]]);
    NSMutableArray* ary = [NSMutableArray array];
    for (id sub_opdata in opdata) {
        [ary addObject:[[self class] encode_to_object_with_type:_optype opdata:sub_opdata]];
    }
    return [ary copy];
}

@end

@interface Tm_map()
{
    id  _key_type;
    id  _value_type;
}
@end

@implementation Tm_map

- (id)initWithKeyType:(id)key_type value_type:(id)value_type
{
    self = [super init];
    if (self)
    {
        _key_type = key_type;
        _value_type = value_type;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert([opdata isKindOfClass:[NSArray class]]);
    opdata = [[self class] sort_opdata_array:opdata optype:_key_type];
    [io write_varint32:(uint64_t)[opdata count]];
    for (id pair in opdata) {
        assert([pair count] == 2);
        [[self class] encode_to_bytes_with_type:_key_type opdata:[pair firstObject] io:io];
        [[self class] encode_to_bytes_with_type:_value_type opdata:[pair lastObject] io:io];
    }
}

- (id)to_object:(id)opdata
{
    assert([opdata isKindOfClass:[NSArray class]]);
    opdata = [[self class] sort_opdata_array:opdata optype:_key_type];
    NSMutableArray* ary = [NSMutableArray array];
    for (id pair in opdata) {
        assert([pair count] == 2);
        id key_value = [[self class] encode_to_object_with_type:_key_type opdata:[pair firstObject]];
        id value_value = [[self class] encode_to_object_with_type:_value_type opdata:[pair lastObject]];
        [ary addObject:@[key_value, value_value]];
    }
    return [ary copy];
}

@end

@interface Tm_set()
{
    id  _optype;
}
@end

@implementation Tm_set

- (id)initWithType:(id)optype
{
    self = [super init];
    if (self)
    {
        _optype = optype;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert(!opdata || [opdata isKindOfClass:[NSArray class]]);
    if (!opdata){
        opdata = [NSArray array];
    }
    [io write_varint32:(uint64_t)[opdata count]];
    for (id sub_opdata in opdata) {
        [[self class] encode_to_bytes_with_type:_optype opdata:sub_opdata io:io];
    }
}

- (id)to_object:(id)opdata
{
    assert(!opdata || [opdata isKindOfClass:[NSArray class]]);
    NSMutableArray* ary = [NSMutableArray array];
    if (opdata){
        for (id sub_opdata in opdata) {
            [ary addObject:[[self class] encode_to_object_with_type:_optype opdata:sub_opdata]];
        }
    }
    return [ary copy];
}

@end

@interface Tm_bytes()
{
    id  _size;
}
@end

@implementation Tm_bytes

- (id)initWithSize:(id)size
{
    self = [super init];
    if (self)
    {
        _size = size;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert([opdata isKindOfClass:[NSData class]]);
    if (_size){
        assert([opdata length] == [_size unsignedIntegerValue]);
        [io write_bytes:opdata with_size:NO];
    }else{
        [io write_bytes:opdata with_size:YES];
    }
}

- (id)to_object:(id)opdata
{
    assert(!_size || [opdata length] == [_size unsignedIntegerValue]);
    return [opdata hex_encode];
}

@end

@interface Tm_optional()
{
    id  _optype;
}
@end

@implementation Tm_optional

- (id)initWithType:(id)optype
{
    self = [super init];
    if (self)
    {
        _optype = optype;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    if (!opdata || [opdata isKindOfClass:[NSNull class]]){
        [io write_u8:0];
    }else{
        [io write_u8:1];
        [[self class] encode_to_bytes_with_type:_optype opdata:opdata io:io];
    }
}

- (id)to_object:(id)opdata
{
    if (!opdata || [opdata isKindOfClass:[NSNull class]]){
        return nil;
    }else{
        return [[self class] encode_to_object_with_type:_optype opdata:opdata];
    }
}

@end

@interface Tm_static_variant()
{
    id  _optypearray;
}
@end

@implementation Tm_static_variant

- (id)nosort
{
    return @YES;
}

- (id)initWithTypeArray:(id)optypearray
{
    self = [super init];
    if (self)
    {
        _optypearray = optypearray;
    }
    return self;
}

- (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert(opdata && [opdata isKindOfClass:[NSArray class]]);
    assert([opdata count] == 2);
    NSUInteger type_id = [[opdata firstObject] unsignedIntegerValue];
    assert(type_id < [_optypearray count]);
    id optype =  [_optypearray objectAtIndex:type_id];
    
    //  1、write typeid  2、write opdata
    [io write_varint32:(uint64_t)type_id];
    [[self class] encode_to_bytes_with_type:optype opdata:[opdata lastObject] io:io];
}

- (id)to_object:(id)opdata
{
    assert(opdata && [opdata isKindOfClass:[NSArray class]]);
    assert([opdata count] == 2);
    NSUInteger type_id = [[opdata firstObject] unsignedIntegerValue];
    assert(type_id < [_optypearray count]);
    id optype =  [_optypearray objectAtIndex:type_id];
    return @[@(type_id), [[self class] encode_to_object_with_type:optype opdata:[opdata lastObject]]];
}

@end

@implementation T_operation

+ (void)to_byte_buffer:(BinSerializer*)io opdata:(id)opdata
{
    assert([opdata isKindOfClass:[NSArray class]]);
    assert([opdata count] == 2);
    id opcode = [opdata firstObject];
    id optype = [self _get_optype_from_opcode:[opcode integerValue]];
    
    //  1、write opcode    2、write opdata
    [io write_varint32:(uint64_t)[opcode unsignedIntegerValue]];
    [[self class] encode_to_bytes_with_type:optype opdata:[opdata lastObject] io:io];
}

+ (id)to_object:(id)opdata
{
    assert([opdata isKindOfClass:[NSArray class]]);
    assert([opdata count] == 2);
    id opcode = [opdata firstObject];
    id optype = [self _get_optype_from_opcode:[opcode integerValue]];
    //  opcode object、opdata object
    return @[opcode, [[self class] encode_to_object_with_type:optype opdata:[opdata lastObject]]];
}

+ (id)_get_optype_from_opcode:(NSInteger)opcode
{
    //    ebo_transfer = 0,           //  转账
    //    ebo_limit_order_create,     //  (创建)限价单
    //    ebo_limit_order_cancel,     //  取消限价单
    //    ebo_call_order_update,      //  更新保证金（抵押借贷）
    //
    //    ebo_fill_order,             //  4
    
    //  TODO:add new op here...
    switch (opcode) {
        case ebo_transfer:
            return [T_transfer class];
        case ebo_limit_order_create:
            return [T_limit_order_create class];
        case ebo_limit_order_cancel:
            return [T_limit_order_cancel class];
        case ebo_call_order_update:
            return [T_call_order_update class];
        case ebo_account_create:
            return [T_account_create class];
        case ebo_account_update:
            return [T_account_update class];
        case ebo_account_upgrade:
            return [T_account_upgrade class];
        case ebo_vesting_balance_create:
            return [T_vesting_balance_create class];
        case ebo_vesting_balance_withdraw:
            return [T_vesting_balance_withdraw class];
        case ebo_proposal_create:
            return [T_proposal_create class];
        case ebo_proposal_update:
            return [T_proposal_update class];
        case ebo_proposal_delete:
            return [T_proposal_delete class];
        case ebo_asset_create:
            return [T_asset_create class];
        case ebo_asset_settle:
            return [T_asset_settle class];
        case ebo_asset_update:
            return [T_asset_update class];
        case ebo_asset_update_bitasset:
            return [T_asset_update_bitasset class];
        case ebo_asset_update_feed_producers:
            return [T_asset_update_feed_producers class];
        case ebo_asset_reserve:
            return [T_asset_reserve class];
        case ebo_asset_issue:
            return [T_asset_issue class];
        case ebo_asset_claim_pool:
            return [T_asset_claim_pool class];
        case ebo_asset_update_issuer:
            return [T_asset_update_issuer class];
        case ebo_htlc_create:
            return [T_htlc_create class];
        case ebo_htlc_redeem:
            return [T_htlc_redeem class];
        case ebo_htlc_extend:
            return [T_htlc_extend class];
        default:
            break;
    }
    assert(false);
    return nil;
}

@end

#pragma mark- 以下为复合数据类型（大部分op都是为复合类型）。

@implementation T_asset

+ (void)register_subfields
{
    [self add_field:@"amount" class:[T_int64 class]];
    [self add_field:@"asset_id" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]];
}

@end

@implementation T_memo_data

+ (void)register_subfields
{
    [self add_field:@"from" class:[T_public_key class]];
    [self add_field:@"to" class:[T_public_key class]];
    [self add_field:@"nonce" class:[T_uint64 class]];
    [self add_field:@"message" class:[[Tm_bytes alloc] initWithSize:nil]];
}

@end

@implementation T_transfer

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"from" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"to" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount" class:[T_asset class]];
    [self add_field:@"memo" class:[[Tm_optional alloc] initWithType:[T_memo_data class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_limit_order_create

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"seller" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount_to_sell" class:[T_asset class]];
    [self add_field:@"min_to_receive" class:[T_asset class]];
    [self add_field:@"expiration" class:[T_time_point_sec class]];
    [self add_field:@"fill_or_kill" class:[T_bool class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_limit_order_cancel

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"fee_paying_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"order" class:[[Tm_protocol_id_type alloc] initWithName:@"limit_order"]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_call_order_update

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"funding_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"delta_collateral" class:[T_asset class]];
    [self add_field:@"delta_debt" class:[T_asset class]];
    [self add_field:@"extensions" class:[[Tm_extension alloc] initWithFieldsDef:@[@{@"name":@"target_collateral_ratio", @"type":[T_uint16 class]}]]];
}

@end

@implementation T_authority

+ (void)register_subfields
{
    [self add_field:@"weight_threshold" class:[T_uint32 class]];
    [self add_field:@"account_auths" class:[[Tm_map alloc] initWithKeyType:[[Tm_protocol_id_type alloc] initWithName:@"account"]
                                                                value_type:[T_uint16 class]]];
    [self add_field:@"key_auths" class:[[Tm_map alloc] initWithKeyType:[T_public_key class] value_type:[T_uint16 class]]];
    [self add_field:@"address_auths" class:[[Tm_map alloc] initWithKeyType:[T_address class] value_type:[T_uint16 class]]];
}

@end

@implementation T_account_options

+ (void)register_subfields
{
    [self add_field:@"memo_key" class:[T_public_key class]];
    [self add_field:@"voting_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"num_witness" class:[T_uint16 class]];
    [self add_field:@"num_committee" class:[T_uint16 class]];
    [self add_field:@"votes" class:[[Tm_set alloc] initWithType:[T_vote_id class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_account_create

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"registrar" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"referrer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"referrer_percent" class:[T_uint16 class]];
    [self add_field:@"name" class:[T_string class]];
    [self add_field:@"owner" class:[T_authority class]];
    [self add_field:@"active" class:[T_authority class]];
    [self add_field:@"options" class:[T_account_options class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_account_update

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"owner" class:[[Tm_optional alloc] initWithType:[T_authority class]]];
    [self add_field:@"active" class:[[Tm_optional alloc] initWithType:[T_authority class]]];
    [self add_field:@"new_options" class:[[Tm_optional alloc] initWithType:[T_account_options class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_account_upgrade

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"account_to_upgrade" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"upgrade_to_lifetime_member" class:[T_bool class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_linear_vesting_policy_initializer

+ (void)register_subfields
{
    [self add_field:@"begin_timestamp" class:[T_time_point_sec class]];
    [self add_field:@"vesting_cliff_seconds" class:[T_uint32 class]];
    [self add_field:@"vesting_duration_seconds" class:[T_uint32 class]];
}

@end

@implementation T_cdd_vesting_policy_initializer

+ (void)register_subfields
{
    [self add_field:@"start_claim" class:[T_time_point_sec class]];
    [self add_field:@"vesting_seconds" class:[T_uint32 class]];
}

@end

@implementation T_vesting_balance_create

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"creator" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"owner" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount" class:[T_asset class]];
    [self add_field:@"policy" class:[[Tm_static_variant alloc] initWithTypeArray:@[[T_linear_vesting_policy_initializer class],
                                                                                   [T_cdd_vesting_policy_initializer class]]]];
}

@end

@implementation T_vesting_balance_withdraw

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"vesting_balance" class:[[Tm_protocol_id_type alloc] initWithName:@"vesting_balance"]];
    [self add_field:@"owner" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount" class:[T_asset class]];
}

@end

@implementation T_op_wrapper

+ (void)register_subfields
{
    [self add_field:@"op" class:[T_operation class]];
}

@end

@implementation T_proposal_create

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"fee_paying_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"expiration_time" class:[T_time_point_sec class]];
    [self add_field:@"proposed_ops" class:[[Tm_array alloc] initWithType:[T_op_wrapper class]]];
    [self add_field:@"review_period_seconds" class:[[Tm_optional alloc] initWithType:[T_uint32 class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_proposal_update

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"fee_paying_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"proposal" class:[[Tm_protocol_id_type alloc] initWithName:@"proposal"]];
    [self add_field:@"active_approvals_to_add" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"active_approvals_to_remove" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"owner_approvals_to_add" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"owner_approvals_to_remove" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"key_approvals_to_add" class:[[Tm_set alloc] initWithType:[T_public_key class]]];
    [self add_field:@"key_approvals_to_remove" class:[[Tm_set alloc] initWithType:[T_public_key class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_proposal_delete

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"fee_paying_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"using_owner_authority" class:[T_bool class]];
    [self add_field:@"proposal" class:[[Tm_protocol_id_type alloc] initWithName:@"proposal"]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_price

+ (void)register_subfields
{
    [self add_field:@"base" class:[T_asset class]];
    [self add_field:@"quote" class:[T_asset class]];
}

@end

@implementation T_asset_options

+ (void)register_subfields
{
    [self add_field:@"max_supply" class:[T_int64 class]];
    [self add_field:@"market_fee_percent" class:[T_uint16 class]];
    [self add_field:@"max_market_fee" class:[T_int64 class]];
    [self add_field:@"issuer_permissions" class:[T_uint16 class]];
    [self add_field:@"flags" class:[T_uint16 class]];
    [self add_field:@"core_exchange_rate" class:[T_price class]];
    [self add_field:@"whitelist_authorities" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"blacklist_authorities" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"whitelist_markets" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"asset"]]];
    [self add_field:@"blacklist_markets" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"asset"]]];
    [self add_field:@"description" class:[T_string class]];
    [self add_field:@"extensions"
              class:[[Tm_extension alloc] initWithFieldsDef:@[@{@"name":@"reward_percent", @"type":[T_uint16 class]},
                                                              @{@"name":@"whitelist_market_fee_sharing", @"type":[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]}]]];
}

@end

@implementation T_bitasset_options

+ (void)register_subfields
{
    [self add_field:@"feed_lifetime_sec" class:[T_uint32 class]];
    [self add_field:@"minimum_feeds" class:[T_uint8 class]];
    [self add_field:@"force_settlement_delay_sec" class:[T_uint32 class]];
    [self add_field:@"force_settlement_offset_percent" class:[T_uint16 class]];
    [self add_field:@"maximum_force_settlement_volume" class:[T_uint16 class]];
    [self add_field:@"short_backing_asset" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_create

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"symbol" class:[T_string class]];
    [self add_field:@"precision" class:[T_uint8 class]];
    [self add_field:@"common_options" class:[T_asset_options class]];
    [self add_field:@"bitasset_opts" class:[[Tm_optional alloc] initWithType:[T_bitasset_options class]]];
    [self add_field:@"is_prediction_market" class:[T_bool class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_settle

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount" class:[T_asset class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_update

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"asset_to_update" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]];
    [self add_field:@"new_issuer" class:[[Tm_optional alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"new_options" class:[T_asset_options class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_update_bitasset

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"asset_to_update" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]];
    [self add_field:@"new_options" class:[T_bitasset_options class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_update_feed_producers

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"asset_to_update" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]];
    [self add_field:@"new_feed_producers" class:[[Tm_set alloc] initWithType:[[Tm_protocol_id_type alloc] initWithName:@"account"]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_reserve

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"payer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount_to_reserve" class:[T_asset class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_issue

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"asset_to_issue" class:[T_asset class]];
    [self add_field:@"issue_to_account" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"memo" class:[[Tm_optional alloc] initWithType:[T_memo_data class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_claim_pool

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"asset_id" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]]; //  fee.asset_id must != asset_id
    [self add_field:@"amount_to_claim" class:[T_asset class]];                              //  only core asset
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_asset_update_issuer

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"asset_to_update" class:[[Tm_protocol_id_type alloc] initWithName:@"asset"]];
    [self add_field:@"new_issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_htlc_create

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"from" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"to" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"amount" class:[T_asset class]];
    [self add_field:@"preimage_hash" class:[[Tm_static_variant alloc] initWithTypeArray:@[
        [[Tm_bytes alloc] initWithSize:@(20)],    //  RMD160
        [[Tm_bytes alloc] initWithSize:@(20)],    //  SHA1 or SHA160
        [[Tm_bytes alloc] initWithSize:@(32)]     //  SHA256
    ]]];
    [self add_field:@"preimage_size" class:[T_uint16 class]];
    [self add_field:@"claim_period_seconds" class:[T_uint32 class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_htlc_redeem

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"htlc_id" class:[[Tm_protocol_id_type alloc] initWithName:@"htlc"]];
    [self add_field:@"redeemer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"preimage" class:[[Tm_bytes alloc] initWithSize:nil]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_htlc_extend

+ (void)register_subfields
{
    [self add_field:@"fee" class:[T_asset class]];
    [self add_field:@"htlc_id" class:[[Tm_protocol_id_type alloc] initWithName:@"htlc"]];
    [self add_field:@"update_issuer" class:[[Tm_protocol_id_type alloc] initWithName:@"account"]];
    [self add_field:@"seconds_to_add" class:[T_uint32 class]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_transaction

+ (void)register_subfields
{
    [self add_field:@"ref_block_num" class:[T_uint16 class]];
    [self add_field:@"ref_block_prefix" class:[T_uint32 class]];
    [self add_field:@"expiration" class:[T_time_point_sec class]];
    [self add_field:@"operations" class:[[Tm_array alloc] initWithType:[T_operation class]]];
    [self add_field:@"extensions" class:[[Tm_set alloc] initWithType:[T_future_extensions class]]];
}

@end

@implementation T_signed_transaction

+ (void)register_subfields
{
    [super register_subfields];
    //  仅比 T_transaction 对象多了 65 字节签名。
    [self add_field:@"signatures" class:[[Tm_array alloc] initWithType:[[Tm_bytes alloc] initWithSize:@(65)]]];
}

@end
