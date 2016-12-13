classdef specs
    properties
        Start
        End
    end
    methods
        function obj = specs(st,en)
            obj.Start = st;
            obj.End   = en;
        end
    end
    enumeration
        NINE_TO_NOON    (struct('hhmm', 930,'type','exact','duration',0), ...
                         struct('hhmm',1200,'type','exact','duration',0))

        NINE_TO_ONE     (struct('hhmm', 930,'type','exact','duration',0),...
                         struct('hhmm',1300,'type','exact','duration',0))

        FIRST           (struct('hhmm', 930,'type','exact','duration',0),...
                         struct('hhmm',1000,'type','exact','duration',0))

        LAST_E          (struct('hhmm',1530,'type','exact','duration',0),...
                         struct('hhmm',1600,'type','exact','duration',0))

        LAST_V          (struct('hhmm',1530,'type','vwap' ,'duration',5),...
                         struct('hhmm',1555,'type','vwap' ,'duration',5))

        AFTERNOON_E     (struct('hhmm',1330,'type','exact','duration',0),...
                         struct('hhmm',1530,'type','exact','duration',0))

        AFTERNOON_V     (struct('hhmm',1330,'type','vwap' ,'duration',5),...
                         struct('hhmm',1525,'type','vwap' ,'duration',5))

        SLAST_V         (struct('hhmm',1500,'type','vwap' ,'duration',5),...
                         struct('hhmm',1525,'type','vwap' ,'duration',5))
    end
end
