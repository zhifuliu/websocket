-module(local_websocket).
-export([start/0]).

start() ->
    case gen_tcp:listen(8181, [binary,{packet,0},{active,true},{reuseaddr,true},{packet_size,1024*2},{keepalive,true}]) of
        {ok,Listen} ->
            spawn(fun()->par_connect(Listen) end);
        _Err ->
            io:format("Accept failed:~w~n", [_Err])
    end.

par_connect(Listen) ->
    {ok,Socket} = gen_tcp:accept(Listen),
    spawn(fun()->par_connect(Listen) end),
    wait(Socket).

wait(Socket) ->
    receive
        {tcp,Socket,Bin} ->
            gen_tcp:send(Socket, list_to_binary(handshake(Bin))),
            loop(Socket);
        Any ->
            io:format("Received(2): ~p~n",[Any]),
            wait(Socket)
    end.

loop(Socket) ->
    receive
        {tcp,Socket,Data} ->
            %% 打印Brorser发送上来的数据
            io:format("Received(3): ~s~n",[websocket_data(Data)]),
            %% 向Brorser发送数据
            gen_tcp:send(Socket, [build_client_data( integer_to_binary(binary_to_integer(websocket_data(Data))*2 ))]),
            loop(Socket);
        Any ->
            io:format("Received(4): ~p~n", [Any]),
            loop(Socket)
    end.

handshake(Bin) ->
    Key = list_to_binary(lists:last(string:tokens(hd(lists:filter(fun(S) -> lists:prefix("Sec-WebSocket-Key:", S) end, string:tokens(binary_to_list(Bin), "\r\n"))), ": "))),
    Accept = base64:encode(crypto:hash(sha,<< Key/binary, "258EAFA5-E914-47DA-95CA-C5AB0DC85B11" >>)),
    %%{ok, Write_log} = file:open("D:/Erlang/erlang_log",[append]),
    %%io:format(Write_log, "Accept: ~s~n", [Accept]),
    [
     "HTTP/1.1 101 Switching Protocols\r\n",
    "connection: Upgrade\r\n",
    "upgrade: websocket\r\n",
    "Blog: http://blog.csdn.net/jom_ch\r\n",
    "sec-websocket-accept: ", Accept, "\r\n",
    "\r\n"
    ].

%% 仅处理长度为125以内的文本消息
websocket_data(Data) when is_list(Data) ->
    websocket_data(list_to_binary(Data));

websocket_data(<< 1:1, 0:3, 1:4, 1:1, Len:7, MaskKey:32, Rest/bits >>) when Len < 126 ->
    <<End:Len/binary, _/bits>> = Rest,
    Text = websocket_unmask(End, MaskKey, <<>>),
    Text;

websocket_data(_) ->
    <<>>.

%% 由于Browser发过来的数据都是mask的,所以需要unmask
websocket_unmask(<<>>, _, Unmasked) ->
    Unmasked;

websocket_unmask(<< O:32, Rest/bits >>, MaskKey, Acc) ->
    T = O bxor MaskKey,
    websocket_unmask(Rest, MaskKey, << Acc/binary, T:32 >>);

websocket_unmask(<< O:24 >>, MaskKey, Acc) ->
    << MaskKey2:24, _:8 >> = << MaskKey:32 >>,
    T = O bxor MaskKey2,
    << Acc/binary, T:24 >>;

websocket_unmask(<< O:16 >>, MaskKey, Acc) ->
    << MaskKey2:16, _:16 >> = << MaskKey:32 >>,
    T = O bxor MaskKey2,
    << Acc/binary, T:16 >>;

websocket_unmask(<< O:8 >>, MaskKey, Acc) ->
    << MaskKey2:8, _:24 >> = << MaskKey:32 >>,
    T = O bxor MaskKey2,
    << Acc/binary, T:8 >>.

%% 发送文本给Client
build_client_data(Data) ->
    Len = iolist_size(Data),
    BinLen = payload_length_to_binary(Len),
    [<< 1:1, 0:3, 1:4, 0:1, BinLen/bits >>, Data].

payload_length_to_binary(N) ->
    case N of
        N when N =< 125 -> << N:7 >>;
        N when N =< 16#ffff -> << 126:7, N:16 >>;
        N when N =< 16#7fffffffffffffff -> << 127:7, N:64 >>
    end.
