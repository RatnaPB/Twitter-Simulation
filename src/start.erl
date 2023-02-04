-module(start).

-export([signIn/0,userRegister/0,start_server/0,handlesignin/0,postTweet/0,subscribetouser/0,signOut/0,
getmentions/0,gethashtag/0,fetchteetsfromsubscribers/0]).

start_server()->
    {ok, Hostname} = inet:gethostname(),
    Server = string:concat("server@", Hostname),

    register(userregister,spawn(list_to_atom(Server),registration,handleRegistration,[#{"" => ""}])),
    register(receiveTweet,spawn(list_to_atom(Server),tweetspassing,getTweet,[#{"" => [""]}])),
    register(hashTagMap,spawn(list_to_atom(Server),tweetspassing,mapHashTag,[#{"" => ""}])),
    register(subscribeToUser,spawn(list_to_atom(Server),registration,mapforsubcribers,[#{"" => []}, #{"" => []}])),
    register(userProcessIdMap,spawn(list_to_atom(Server),registration,userProcessIdMap,[#{"" => ""}])).

signIn() ->
    registration:signin().

userRegister()->
    registration:userregistration().

handlesignin()->
    receive
        % for SignIn
        {UserName,PasswordAndProcess,Pid}->
            userregister ! {UserName,PasswordAndProcess,self(),Pid, signin};
        % for Registeration    
        {UserName,PassWord,Pid,register}->
            userregister ! {UserName,PassWord,self(),Pid, register};
        % For receiving user's tweets and quering them        
        {UserName,Tweet,Pid,tweet}->
            if
                UserName==querying ->
                    hashTagMap!{Tweet,self(),Pid}; 
                UserName==queryingSubscribedTweets->
                    % Tweet is UserName
                    subscribeToUser!{Tweet,self(),Pid,tweet}; 
                true ->
                 receiveTweet !{UserName,Tweet,self(),Pid} 
            end;
        {UserName,Pid}->
            if 
                Pid==signOut->
                    [UserName1,RemoteNodePid]=UserName,
                    userProcessIdMap!{UserName1,RemoteNodePid,self(),signOutUser};
                true->
                 receiveTweet !{UserName,self(),Pid}
            end;     
%%        {Pid}->
%%            userregister ! {self(),Pid,"goodMorningMate"};
        {UserName,CurrrentUserName,Pid,PidOfReceive}->
            subscribeToUser ! {UserName,CurrrentUserName,PidOfReceive,self(),Pid}
    end,
    receive
        {Message,Pid1}->
            Pid1 ! {Message},
            handlesignin()
    end.

subscribetouser()->
    {ok,[UserName]}=io:fread("Enter the username to subscribe - ","~ts"),
    registration:usersubcribe(UserName).

postTweet()->
    Tweet1=io:get_line("Enter tweet to post - "),
    Tweet=lists:nth(1,string:tokens(Tweet1,"\n")),
    try tweetspassing:sendTweet(Tweet)
    catch
        error:_ ->
            io:format("Please sign in to post the tweet ~n")
    end.

signOut()->
    registration:signOutUser().

getmentions()->
    tweetspassing:getmentions().

fetchteetsfromsubscribers()->
    tweetspassing:fetchsubcribedtweets().

gethashtag()->
    {ok,[HashTag]}=io:fread("Enter the hashtag(with #) - ","~ts"),
    tweetspassing:gethashtag(HashTag).






