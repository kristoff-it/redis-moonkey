const std = @import("std");
const redis = @cImport({
    @cInclude("redismodule.h");
});

// MK.EVALKEY scriptkey numkeys [key ...] [arg ...]
pub export fn MK_EVALKEY(ctx: ?*redis.RedisModuleCtx, argv: [*c]?*redis.RedisModuleString, argc: c_int) c_int {
    const not_enough_args = argc < 3;
    if (1 == redis.RedisModule_IsKeysPositionRequest.?(ctx)) {
        if (not_enough_args) {
            return redis.REDISMODULE_OK;
        }

        // We know we can access numkeys
        var numkeys: c_longlong = undefined;
        if (redis.REDISMODULE_ERR == redis.RedisModule_StringToLongLong.?(argv[2], &numkeys)) {
            return redis.REDISMODULE_OK;
        }

        // If numkeys is a plausible number
        if (numkeys <= argc - 3) {
            redis.RedisModule_KeyAtPos.?(ctx, 1);
            var i: c_int = 0;
            while (i < numkeys) : (i += 1) {
                redis.RedisModule_KeyAtPos.?(ctx, 3 + i);
            }
        }

        return redis.REDISMODULE_OK;
    }
    // We need at least 3 arguments
    if (not_enough_args) return redis.RedisModule_WrongArity.?(ctx);

    // We open striptkey
    const key = @ptrCast(?*redis.RedisModuleKey, redis.RedisModule_OpenKey.?(ctx, argv[1], redis.REDISMODULE_READ));
    defer redis.RedisModule_CloseKey.?(key);

    // We return an error if it's not a string key
    const keytype = redis.RedisModule_KeyType.?(key);
    if (keytype != redis.REDISMODULE_KEYTYPE_STRING) {
        return redis.RedisModule_ReplyWithError.?(ctx, redis.REDISMODULE_ERRORMSG_WRONGTYPE);
    }

    // Read the key value
    var len: usize = undefined;
    const script = redis.RedisModule_StringDMA.?(key, &len, redis.REDISMODULE_READ);

    // Call EVAL
    const reply = redis.RedisModule_Call.?(ctx, "EVAL", "bv", script, len, &argv[2], @intCast(usize, argc - 2));
    defer redis.RedisModule_FreeCallReply.?(reply);

    // Return exactly what the Lua script returned
    return redis.RedisModule_ReplyWithCallReply.?(ctx, reply);
}

pub export fn RedisModule_OnLoad(ctx: *redis.RedisModuleCtx, argv: [*c]?*redis.RedisModuleString, argc: c_int) c_int {
    if (redis.RedisModule_Init(ctx, "moonkey", 1, redis.REDISMODULE_APIVER_1) == redis.REDISMODULE_ERR)
        return redis.REDISMODULE_ERR;
    if (redis.RedisModule_CreateCommand.?(ctx, "mk.evalkey", MK_EVALKEY, "getkeys-api no-cluster", 0, 0, 0) == redis.REDISMODULE_ERR)
        return redis.REDISMODULE_ERR;
    return redis.REDISMODULE_OK;
}
