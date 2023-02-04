-module(registration).

-export([userregistration/0,handleRegistration/1,signin/0,mapforsubcribers/2,usersubcribe/1,userProcessIdMap/1
,signOutUser/0]).

handleRegistration(UserPasswordMap)->
    receive
        {UserName,PassWord,Pid,RemoteNodePid, register}->
            User=maps:find(UserName,UserPasswordMap),
            if
                User==error->
                    NewUserMap=maps:put(UserName,PassWord,UserPasswordMap), 
                    receiveTweet ! {UserName},
                    Pid ! {"User registered successfully!",RemoteNodePid},
                    handleRegistration(NewUserMap);
                true ->
                    Pid ! {"User is already registered.",RemoteNodePid},
                    handleRegistration(UserPasswordMap)
            end;
        {UserName,PasswordAndProcess,Pid,RemoteNodePid, signin}->
%%            UserPassword=maps:find(UserName,UserPasswordMap),
%%            [Pass,Process]=PasswordAndProcess,
%%            ListPassWord={ok,Pass},
            {ok, UserPassword}=maps:find(UserName,UserPasswordMap),
            [Pass,Process]=PasswordAndProcess,
            if
                UserPassword==Pass->
                    userProcessIdMap!{UserName,Process, signIn},
                    Pid ! {"User signed in successfully!",RemoteNodePid};
                true ->
                    Pid ! {"Incorrect UserName or Password.",RemoteNodePid}
            end,
            handleRegistration(UserPasswordMap)
%%        {UserName,Pid}->
%%            User=maps:find(UserName,UserPasswordMap),
%%            if
%%                User==error->
%%                    Pid ! {"ok"};
%%                true ->
%%                    Pid ! {"not ok"}
%%            end,
%%            recieveMessage(UserPasswordMap);
%%        {Pid,RemoteNodePid,_}->
%%            UserList=maps:to_list(UserPasswordMap),
%%            Pid ! {UserList,RemoteNodePid},
%%            recieveMessage(UserPasswordMap)
    end.

getalltweets(UserSubscriberMap,SubscribersUserMap,SubscribersTo,AllTweets,Index,Pid,RemoteNodePid)->
    if
        Index>length(SubscribersTo) ->
            Pid ! {AllTweets,RemoteNodePid}; 
        true ->
            CurrentUserName=lists:nth(Index,SubscribersTo),
            receiveTweet ! {CurrentUserName,self()},
            receive
                {Tweets}->
                    AppendTweet=[{CurrentUserName,Tweets}],
%%                    io:format("~p~n",[AppendTweet]),
                    AllTweets1=lists:append(AllTweets,AppendTweet),
                    getalltweets(UserSubscriberMap,SubscribersUserMap,SubscribersTo,AllTweets1,Index+1,Pid,RemoteNodePid)
            end       
     end.

usersubcribe(UserName)->
    SignedIn=persistent_term:get("SignedIn"),
    if
        SignedIn==true->
            ServerId=persistent_term:get("ServerId"),
            ServerId!{UserName,persistent_term:get("UserName"),self(),whereis(receiveTweetFromUser)},
            receive
                {Registered}->
                    io:format("~p~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call start:startTheRegistration() to complete signin~n")
    end.

mapforsubcribers(UserSubscriberMap,SubscribersUserMap)->
    receive
        {UserName,CurrentUserName,CurrentUserPid,Pid,RemoteNodePid}->
            ListSubscribedTo=maps:find(CurrentUserName,SubscribersUserMap),
            ListSubscribers=maps:find(UserName,UserSubscriberMap),
            if
                ListSubscribers==error->
                    NewUserSubscriberMap=maps:put(UserName,[{CurrentUserName,CurrentUserPid}],UserSubscriberMap),
                    Pid ! {"Subscribed",RemoteNodePid},
                    if
                        ListSubscribedTo==error ->
                            NewSubscriberUserMap=maps:put(CurrentUserName,[{UserName}],SubscribersUserMap),
                            mapforsubcribers(NewUserSubscriberMap,NewSubscriberUserMap);
                        true ->
                            {ok,SubscribersTo}=ListSubscribedTo,
                            SubscribersTo1=lists:append(SubscribersTo,[{UserName}]),
%%                        io:format("~p~n",[SubscribersTo1]),
                            NewSubscriberUserMap=maps:put(CurrentUserName,SubscribersTo1,SubscribersUserMap),
                            mapforsubcribers(NewUserSubscriberMap,NewSubscriberUserMap)
                    end;
                true ->
                    {ok,Subscribers}=ListSubscribers,
                    Subscribers1=lists:append(Subscribers,[{CurrentUserName,CurrentUserPid}]),
                    NewUserSubscriberMap=maps:put(UserName,Subscribers1,UserSubscriberMap),
                    Pid ! {"Subscribed",RemoteNodePid},
                    if
                        ListSubscribedTo==error ->
                            NewSubscriberUserMap=maps:put(CurrentUserName,[{UserName}],SubscribersUserMap),
                            mapforsubcribers(NewUserSubscriberMap,NewSubscriberUserMap);
                        true ->
                            {ok,SubscribersTo}=ListSubscribedTo,
                            SubscribersTo1=lists:append(SubscribersTo,[{UserName}]),
%%                        io:format("~p~n",[SubscribersTo1]),
                            NewSubscriberUserMap=maps:put(CurrentUserName,SubscribersTo1,SubscribersUserMap),
                            mapforsubcribers(NewUserSubscriberMap,NewSubscriberUserMap)
                    end
            end;
        {UserName,Pid}->
            ListSubscribers=maps:find(UserName,UserSubscriberMap),
            if
                ListSubscribers==error->
                    Pid !{[]};
                true->
                    {ok,Subscribers}=ListSubscribers,
                    Pid ! {Subscribers}
            end,
            mapforsubcribers(UserSubscriberMap,SubscribersUserMap);
        {UserName,Pid,RemoteNodePid,tweet}->
            ListSubscribersTo=maps:find(UserName,SubscribersUserMap),
%%        io:format("I am here"),
            if
                ListSubscribersTo==error->
                    Pid !{[]};
                true->
                    {ok,SubscribersTo}=ListSubscribersTo,
%%                io:format("~p~n",[SubscribersTo]),
                    getalltweets(UserSubscriberMap,SubscribersUserMap,
                        SubscribersTo,[],1,Pid,RemoteNodePid)
            end,
            mapforsubcribers(UserSubscriberMap,SubscribersUserMap)
    end.

userProcessIdMap(UserProcessIdMap)->
    receive
    {UserName,CurrentUserPid,signIn}->
        NewUserProcessIdMap=maps:put(UserName,CurrentUserPid,UserProcessIdMap),
        userProcessIdMap(NewUserProcessIdMap); 
    {UserName,RemoteNodePid,Pid,signOutUser}->
        ListSubscribers=maps:find(UserName,UserProcessIdMap),
        if
            ListSubscribers==error->
                Pid ! {"",RemoteNodePid},
                userProcessIdMap(UserProcessIdMap); 
            true ->
                NewUserProcessIdMap=maps:remove(UserName,UserProcessIdMap),
                Pid ! {"User signed out successfully!",RemoteNodePid},

                userProcessIdMap(NewUserProcessIdMap)     
        end;
    {UserName,Tweet,UserName1,mention,tweet}->
        io:format("~p~n",[UserName]),
        ListSubscribers=maps:find(UserName,UserProcessIdMap),
        if
            ListSubscribers==error->
                ok;
            true->
                {ok,ProcessId}=ListSubscribers,
                ProcessId ! {Tweet,UserName1}
        end,
        userProcessIdMap(UserProcessIdMap)
    end.

signOutUser()->
    SignedIn=persistent_term:get("SignedIn"),
    if
        SignedIn==true->
            ServerId=persistent_term:get("ServerId"),
            ServerId!{[persistent_term:get("UserName"),self()],signOut},
            receive
                {Registered}->
                    persistent_term:erase("UserName"),
                    io:format("~s~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call start:startTheRegistration() to complete signin~n")
    end.

signin()->
    {ok, Hostname} = inet:gethostname(),
    Server = string:concat("server@", Hostname),
    {ok,[UserName]}=io:fread("Username - ","~ts"),
    {ok,[PassWord]}=io:fread("Password - ","~ts"),
    ServerConnectionId=spawn(list_to_atom(Server),start,handlesignin,[]),
    persistent_term:put("ServerId", ServerConnectionId),
    register(receiveTweetFromUser,spawn(tweetspassing,getusertweet,[])),
    List4=[{"a",[]}],
    Map6=maps:from_list(List4),
    register(tweetMap,spawn(tweetspassing,tweetMap,[Map6,1])),
    ServerConnectionId!{UserName,[PassWord,whereis(receiveTweetFromUser)],self()},
    receive
        {Registered}->
            if
                Registered=="User signed in successfully!"->
                    persistent_term:put("UserName",UserName),
                    persistent_term:put("SignedIn",true);
                true->
                    persistent_term:put("SignedIn",false)
            end,
            io:format("~s~n",[Registered])
    end.

userregistration()->
    {ok, Hostname} = inet:gethostname(),
    Server = string:concat("server@", Hostname),
    {ok,[UserName]}=io:fread("Username - ","~ts"),
    {ok,[PassWord]}=io:fread("Password - ","~ts"),
    ServerConnectionId=spawn(list_to_atom(Server),start,handlesignin,[]),
    ServerConnectionId ! {UserName,PassWord,self(),register},
    receive
        {Registered}->
            io:format("~s~n",[Registered])
    end.








