-module(tweetspassing).

-export([sendTweet/1,getTweet/1,mapHashTag/1,tweetparsing/5,getusertweet/0,
  sendtoall/4,getmentions/0,gethashtag/1,printTweets/2,fetchsubcribedtweets/0,handleTweets/5,tweetMap/2]).


getTweet(UserTweetMap)->
    receive
        {UserName,Tweet,Pid,RemoteNodePid}->
            NewUserTweetMap=tweetspassing:handleTweets(UserName,Tweet,Pid,RemoteNodePid,UserTweetMap),
          getTweet(NewUserTweetMap);
         {UserName}->
            NewUserTweetMap=maps:put(UserName,[],UserTweetMap),
           getTweet(NewUserTweetMap);
         {UserName1,Pid}->
            {UserName}=UserName1,
            ListTweets=maps:find(UserName,UserTweetMap),
            if
                ListTweets==error->
                    Pid ! {[]};
                true ->
                    {ok,Tweets}=ListTweets,
                    Pid ! {Tweets}
            end,
           getTweet(UserTweetMap);
         {UserName,Pid,RemoteNodePid}->
            ListTweets=maps:find(UserName,UserTweetMap),
            if
                ListTweets==error->
                    Pid ! {[],RemoteNodePid};
                true ->
                    {ok,Tweets}=ListTweets,
                    Pid ! {Tweets,RemoteNodePid}
            end,
           getTweet(UserTweetMap)

    end.

sendTweet(Tweet)->
  try persistent_term:get("SignedIn")
  catch
    error:X ->
      io:format("~p~n",[X])
  end,
  SignedIn=persistent_term:get("SignedIn"),
  if
    SignedIn==true->
      ServerId=persistent_term:get("ServerId"),
      ServerId!{persistent_term:get("UserName"),Tweet,self(),tweet},
      receive
        {Registered}->
          io:format("~s~n",[Registered])
      end;
    true->
      io:format("First sign in to access this functionality ~n")
  end.

tweetparsing(SplitTweet,Index,Tweet,UserName,Tag)->
    if
        Index==length(SplitTweet)+1 ->
         ok;
        true ->
            CurrentString=string:find(lists:nth(Index,SplitTweet),Tag,trailing),
            if
                CurrentString==nomatch ->
                  ok;  
                true ->
                    if
                        Tag=="@" ->
                            UserName1=string:sub_string(CurrentString,2,length(CurrentString)),
                            userProcessIdMap!{UserName1,Tweet,UserName,mention,tweet};
                        true ->
                            ok
                    end,
                    hashTagMap ! {CurrentString,Tweet,UserName,addnewhashTag}  
            end,
            tweetparsing(SplitTweet,Index+1,Tweet,UserName,Tag)
    end.

handleTweets(UserName,Tweet,Pid,RemoteNodePid,UserTweetMap)->
  ListTweets=maps:find(UserName,UserTweetMap),
  {ok,Tweets}=ListTweets,
  Tweets1=lists:append(Tweets,[Tweet]),
  NewUserTweetMap=maps:put(UserName,Tweets1,UserTweetMap),
  Pid ! {"Tweet posted successfully!",RemoteNodePid},
  TweetSplitList=string:split(Tweet," ",all),
  tweetparsing(TweetSplitList,1,Tweet,UserName,"#"),
  tweetparsing(TweetSplitList,1,Tweet,UserName,"@"),

  subscribeToUser ! {UserName,self()},
  receive
    {Subscribers}->
      spawn(tweetspassing,sendtoall,[Subscribers,1,Tweet,UserName])
  end,
  NewUserTweetMap.

sendtoall(Subscribers,Index,Tweet,UserName)->
  if
    Index>length(Subscribers)->
      ok;
    true->
      {Username1,_}=lists:nth(Index,Subscribers),
      userProcessIdMap!{Username1,Tweet,UserName,mention,tweet},
      sendtoall(Subscribers,Index+1,Tweet,UserName)
  end.

mapHashTag(HashTagTweetMap)->
  receive
    {HashTag,Tweet,UserName,addnewhashTag}->
      io:format("~s~n",[Tweet]),
      ListTweets=maps:find(HashTag,HashTagTweetMap),
      if
        ListTweets==error->
          NewHashTagTweetMap=maps:put(HashTag,[{Tweet,UserName}],HashTagTweetMap),
          mapHashTag(NewHashTagTweetMap);
        true ->
          {ok,Tweets}=ListTweets,
          Tweets1=lists:append(Tweets,[{Tweet,UserName}]),
          NewHashTagTweetMap=maps:put(HashTag,Tweets1,HashTagTweetMap),
          mapHashTag(NewHashTagTweetMap)
      end;
    {HashTag,Pid,RemoteNodePid}->
      ListTweets=maps:find(HashTag,HashTagTweetMap),
      if
        ListTweets==error->
          Pid ! {[],RemoteNodePid};
        true ->
          {ok,Tweets}=ListTweets,
          Pid ! {Tweets,RemoteNodePid}
      end,
      mapHashTag(HashTagTweetMap)
  end.

getmentions()->
    UserId="@"++persistent_term:get("UserName"),
    ServerId=persistent_term:get("ServerId"),
    ServerId!{querying,UserId,self(),tweet},
    receive
        {Tweets}->
            printTweets(Tweets,1) 
    end.

getusertweet()->
  receive
    {Message,UserName}->
      tweetMap!{UserName,Message},
      getusertweet()
  end.

printTweets(Tweets,Index)->
    if
        Index>length(Tweets) ->
            ok;
        true ->
            {Tweet,UserName}=lists:nth(Index,Tweets),
            tweetMap!{UserName,Tweet},
            printTweets(Tweets,Index+1)
    end.

gethashtag(Tag)->
  ServerId=persistent_term:get("ServerId"),
  ServerId!{querying,Tag,self(),tweet},
  receive
    {Tweets}->
      printTweets(Tweets,1)
  end.

fetchsubcribedtweets()->
  ServerId=persistent_term:get("ServerId"),
  ServerId!{queryingSubscribedTweets,persistent_term:get("UserName"),self(),tweet},
    receive
        {Tweets}->
            formatfetchedtweets(Tweets,1)
    end.

tweetMap(TweetIdMap,Index)->
  receive
    {UserName,Tweet}->
      TweetId="Tweet"++  integer_to_list(Index),
      NewUserMap=maps:put(TweetId,[UserName,Tweet],TweetIdMap),
      io:format("~p : ~p ~n",[UserName,Tweet]),
      tweetMap(NewUserMap,Index+1)
  end.

formatfetchedtweets(Tweets,UserIndex)->
        if
            UserIndex>length(Tweets) ->
                ok;
            true ->
                CurrentUserTweets=lists:nth(UserIndex,Tweets),
                {{UserName},CurrentTweets}=CurrentUserTweets,
              formatandprintTweet(CurrentTweets,1,UserName),
              formatfetchedtweets(Tweets,UserIndex+1)
        end.

formatandprintTweet(Tweets,Index,UserName)->
    if
        Index>length(Tweets) ->
            ok;
        true ->
            Tweet = lists:nth(Index,Tweets),
            tweetMap!{UserName,Tweet},
            formatandprintTweet(Tweets,Index+1,UserName)
    end.


 




       



    



 