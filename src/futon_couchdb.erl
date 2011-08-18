%% Handle Futon requests dynamically

-module(futon_couchdb).
-author('Jason Smith <jhs@iriscouch.com>').

-include("couch_db.hrl").

-export([handle_futon_req/1]).

-define(MOBILE_UA_RE,
"android|avantgo|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino"
).

-define(MOBILE_UA_TRUNC_RE,
"1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|e\-|e\/|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|xda(\-|2|g)|yas\-|your|zeto|zte\-"
).


handle_futon_req(#httpd{}=Req) -> ok
    %, ?LOG_DEBUG("Received Futon request:\n~p", [Req])
    , case couch_config:get("httpd", "mobile_futon")
        of "true" -> ok
            , handle_futon_req(mobile, Req)
        ; _ -> ok
            % Mobile futon is disabled in the config.
            , browser_futon(Req)
        end
    .

handle_futon_req(mobile, Req) -> ok
    , case code:priv_dir(?MODULE)
        of {error, bad_name} -> ok
            , ?LOG_DEBUG("Cannot find futon_couchdb priv dir", [])
            , browser_futon(Req)
        ; Priv_dir -> ok
            , Mobile_dir = Priv_dir ++ "/mobilefuton"
            , case httpd_conf:is_directory(Mobile_dir)
                of {ok, Mobile_dir} -> ok
                    , mobile_enabled_futon(Req, Mobile_dir)
                ; Else -> ok
                    , ?LOG_DEBUG("Bad mobilefuton dir ~p: ~p", [Mobile_dir, Else])
                    , browser_futon(Req)
                end
        end
    .


mobile_enabled_futon(#httpd{mochi_req=MochiReq}=Req, Mobile_dir) -> ok
    , case MochiReq:get_header_value("user-agent")
        of undefined -> ok
            , browser_futon(Req)
        ; Unknown when not is_list(Unknown) -> ok
            , ?LOG_ERROR("Unknown user-agent: ~p", [Unknown])
            , browser_futon(Req)
        ; User_agent -> ok
            , ?LOG_DEBUG("Considering mobile futon\n~p", [User_agent])
            , case re:run(User_agent, ?MOBILE_UA_RE, [caseless])
                of {match, _Match1} -> ok
                    , ?LOG_DEBUG("Mobile browser first match: ~s", [User_agent])
                    , mobile_futon(Req, Mobile_dir)
                ; nomatch -> ok
                    , First_4 = string:substr(User_agent, 1, 4)
                    , case re:run(First_4, ?MOBILE_UA_TRUNC_RE, [caseless])
                        of {match, _Match2} -> ok
                            , ?LOG_DEBUG("Mobile browser second match: ~s", [User_agent])
                            , mobile_futon(Req, Mobile_dir)
                        ; nomatch -> ok
                            , ?LOG_DEBUG("Not a mobile browser: ~s", [User_agent])
                            , browser_futon(Req)
                        end
                end
        end
    .

mobile_futon(Req, Mobile_dir) -> ok
    , send_from_dir(Req, Mobile_dir)
    .


browser_futon(#httpd{}=Req) -> ok
    , case couch_config:get("httpd", "sammy_futon")
        of "true" -> ok
            , sammy_futon(Req)
        ; _Not_true -> ok
            % Sammy Futon is disabled in the config. Check for the hostname dot easter egg, "foo.iriscouch.com."
            %, ?LOG_INFO("HOST HAS DOT: ~p", [host_has_dot(Req)])
            , case host_has_dot(Req)
                of true -> sammy_futon(Req)
                ; false -> old_futon(Req)
                end
        end
    .


%sammy_futon(#httpd{method='GET', requested_path_parts=[<<"_utils">>,<<"image">>,<<"logo.png">>]}=Req) -> ok
%    % This avoids having to modify the filesystem, thus avoiding future imports overwriting changes.
%    , Mochi_req = Req#httpd.mochi_req
%    , Logo_path = "/_utils/image/iris_couch.png"
%    , New_mochi_req = mochiweb_request:new( Mochi_req:get(socket)
%                                          , Mochi_req:get(method)
%                                          , Logo_path
%                                          , Mochi_req:get(version)
%                                          , Mochi_req:get(oob)
%                                          , Mochi_req:get(headers)
%                                          )
%    %, ?LOG_DEBUG("MochiReq:\n~p", [MochiReq:get(path)])
%    , Logo = [ <<"_utils">>, <<"image">>, <<"iris_couch.png">> ]
%    , Iris_req = Req#httpd{ requested_path_parts = Logo
%                          , path_parts           = Logo
%                          , mochi_req            = New_mochi_req
%                          }
%
%    , sammy_futon(Iris_req)
%    ;

sammy_futon(#httpd{}=Req) -> ok
    %, ?LOG_DEBUG("Req requested_path_parts:\n~p", [Req#httpd.requested_path_parts])
    %, ?LOG_DEBUG("Req path_parts:\n~p", [Req#httpd.path_parts])
    , case code:priv_dir(?MODULE)
        of {error, bad_name} -> ok
            , ?LOG_DEBUG("Cannot find ~p priv dir", [?MODULE])
            , old_futon(Req)
        ; Priv_dir -> ok
            , Sammy_dir = Priv_dir ++ "/sammy_futon"
            , case httpd_conf:is_directory(Sammy_dir)
                of {ok, Sammy_dir} -> ok
                    , ?LOG_DEBUG("Serving Sammy Futon: ~s", [Sammy_dir])
                    , send_from_dir(Req, Sammy_dir)
                ; Else -> ok
                    , ?LOG_DEBUG("Bad sammy_futon dir ~p: ~p", [Sammy_dir, Else])
                    , old_futon(Req)
                end
        end
    .


old_futon(#httpd{}=Req) -> ok
    % XXX: For now, use the same config as favicon.ico.
    , case couch_config:get("httpd_global_handlers", "favicon.ico")
        of undefined -> ok
            , ?LOG_ERROR("Cannot find httpd_global_handlers/favicon.ico config", [])
            , send_500(Req, "We screwed up! Please email support@iriscouch.com and we will fix it ASAP")
        ; Favicon_cfg -> ok
            , case couch_util:parse_term(Favicon_cfg)
                of {ok, {_Mod, _Func, Futon_dir}} -> ok
                    %, ?LOG_DEBUG("~p:~p ~p", [Mod, Func, Futon_dir])
                    , send_from_dir(Req, Futon_dir)
                ; _ -> ok
                    , ?LOG_ERROR("Bad favicon config: ~p", [Favicon_cfg])
                    , send_500(Req, "We screwed up! Please email support@iriscouch.com and we will fix it ASAP")
                end
        end
    .


send_from_dir(Req, Dir) -> ok
    , couch_httpd_misc_handlers:handle_utils_dir_req(Req, Dir)
    .

%
% Utilities
%

%send_500(Req) -> ok
%    , send_500(Req, "not_implmented")
%    .

send_500(Req, Msg) when is_list(Msg) -> ok
    , send_500(Req, list_to_binary(Msg))
    ;

send_500(Req, Msg) -> ok
    , couch_httpd:send_json(Req, 500, {[{error, Msg}]})
    .

host_has_dot(#httpd{mochi_req=MochiReq}) -> ok
    , host_has_dot(header, MochiReq:get_header_value("host"))
    .

host_has_dot(header, Host) when not is_list(Host) -> ok
    , false
    ;

host_has_dot(header, Host) -> ok
    , case string:tokens(Host, ":")
        of [Hostname, _] when is_list(Hostname) -> host_has_dot(hostname, Hostname)
        ;  [Hostname]    when is_list(Hostname) -> host_has_dot(hostname, Hostname)
        ;  _ -> false
        end
    ;

host_has_dot(hostname, Hostname) -> ok
    , lists:suffix(".", Hostname)
    .

% vim: sw=4 sts=4 et
