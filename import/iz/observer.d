module iz.observer;

import iz.types;
import iz.containers;

/**
 * Subject (one to many) interface.
 */
interface izSubject
{
    /// determines if anObserver is suitable for this subject.
    bool acceptObserver(Object anObserver);
    /// an observer can be added. it can to be tested with acceptObserver.
    void addObserver(Object anObserver);
    /// an observer wants to be removed.
    void removeObserver(Object anObserver);
    /// sends all data the observers are monitoring.
    void updateObservers();
}

/**
 * izCustomSubject handles a list of obsever.
 * Params:
 * OT = the observer type, either an interface or a class.
 */
class izCustomSubject(OT): izSubject
if (is(OT == interface) || is(OT == class))
{
    protected
    {
        izDynamicList!OT fObservers;
    }
    public
    {
        this()
        {
            fObservers = construct!(izDynamicList!OT);
        }

        ~this()
        {
            fObservers.destruct;
        }

        void updateObservers()
        {
            /*virtual: send all values*/
        }

        bool acceptObserver(Object anObserver)
        {
            return (cast(OT) anObserver !is null);
        }

        void addObserver(Object anObserver)
        {
            if (!acceptObserver(anObserver))
                return;
            auto obs = cast(OT) anObserver;
            if (fObservers.find(obs) != -1)
                return;
            fObservers.add(obs);
        }

        void addObservers(Objs...)(Objs objs)
        {
            foreach(obj; objs)
                addObserver(obj);
        }

        void removeObserver(Object anObserver)
        {
            auto obs = cast(OT) anObserver;
            if (obs) fObservers.remove(obs);
        }
    }
}

/**
 * izObserverInterconnector is in charge for inter-connecting
 * some subjects with their observers, whatever their specializations are.
 */
class izObserverInterconnector
{
    private
    {
        izDynamicList!Object fObservers;
        izDynamicList!Object fSubjects;
        ptrdiff_t fUpdateCount;
    }
    public
    {
        this()
        {
            fObservers = construct!(izDynamicList!Object);
            fSubjects = construct!(izDynamicList!Object);
        }

        ~this()
        {
            fObservers.destruct;
            fSubjects.destruct;
        }

        /** 
         * Several subjects or observers will be added.
         * Avoid any superfluous updates while adding.
         * Every beginUpdate() must be followed by an endUpdate.
         */
        void beginUpdate()
        {
            ++fUpdateCount;
        }

        /** 
         * Several subjects or observers have been added.
         * Decrements a counter and update the entities if it's equal to 0.
         */
        void endUpdate()
        {
            --fUpdateCount;
            if (fUpdateCount > 0) return;
            updateAll;
        }

        /**
         * Add anObserver to the entity list.
         */
        void addObserver(Object anObserver)
        {
            if (fObservers.find(anObserver) != -1) return;
            beginUpdate;
            fObservers.add(anObserver);
            endUpdate;
        }
        
        /**
         * Adds the list of observer objs to the entity list.
         * Optimized for bulk adding.
         */
        void addObservers(Objs...)(Objs objs)
        {
            beginUpdate;
            foreach(obj; objs) addObserver(obj);
            endUpdate;
        }

        /**
         * Removes anObserver from the entity list.
         */
        void removeObserver(Object anObserver)
        {
            beginUpdate;
            fObservers.remove(anObserver);
            for (auto i = 0; i < fSubjects.count; i++)
                (cast(izSubject) fSubjects[i]).removeObserver(anObserver);
            endUpdate;
        }

        /**
         * Adds aSubject to the entity list.
         */
        void addSubject(Object aSubject)
        {
            if (fSubjects.find(aSubject) != -1) return;
            if( (cast(izSubject) aSubject) is null) return;
            beginUpdate;
            fSubjects.add(aSubject);
            endUpdate;
        }

        /**
         * Adds the list of subject subjs to the entity list.
         * Optimized for bulk adding.
         */
        void addSubjects(Subjs...)(Subjs subjs)
        {
            beginUpdate;
            foreach(subj; subjs) addSubject(subj);
            endUpdate;
        }

        /**
         * Removes aSubject from the entity list.
         */
        void removeSubject(Object aSubject)
        {
            beginUpdate;
            fSubjects.remove(aSubject);
            endUpdate;
        }

        /**
         * Updates the connections between the entities stored in the global list. 
         * Usually has not be called manually.
         * During the process, each subject kept in global list will be visited
         * by each observer of the global list.
         */
        void updateObservers()
        {
            fUpdateCount = 0;
            for(auto subjectIx = 0; subjectIx < fSubjects.count; subjectIx++)
            {
                auto subject = cast(izSubject) fSubjects[subjectIx];
                for(auto observerIx = 0; observerIx < fObservers.count; observerIx++)
                {
                    subject.addObserver(fObservers[observerIx]);
                }
            }
        }

        /// ditto
        alias updateAll = updateObservers;
    }
}

version(unittest)
{
    interface PropObserver(T)
    {
        void min(T aValue);
        void max(T aValue);
        void def(T aValue);
    }
    alias intPropObserver = PropObserver!int;

    class foo: intPropObserver
    {
        int _min, _max, _def;
        void min(int aValue){_min = aValue;}
        void max(int aValue){_max = aValue;}
        void def(int aValue){_def = aValue;}
    }
    alias uintPropObserver = PropObserver!uint;

    class bar: uintPropObserver
    {
        uint _min, _max, _def;
        void min(uint aValue){_min = aValue;}
        void max(uint aValue){_max = aValue;}
        void def(uint aValue){_def = aValue;}
    }

    class intPropSubject : izCustomSubject!intPropObserver
    {
        int _min = int.min; 
        int _max = int.max;
        int _def = int.init; 
        final override void updateObservers()
        {
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).min(_min);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).max(_max);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).def(_def);
        }
    }

    class uintPropSubject : izCustomSubject!uintPropObserver
    {
        uint _min = uint.min; 
        uint _max = uint.max;
        uint _def = uint.init; 
        final override void updateObservers()
        {
            for(auto i = 0; i < fObservers.count; i++)
                (cast(uintPropObserver)fObservers[i]).min(_min);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(uintPropObserver)fObservers[i]).max(_max);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(uintPropObserver)fObservers[i]).def(_def);
        }
    }

    unittest
    {
        auto nots1 = construct!Object;
        auto nots2 = construct!Object;
        auto inter = construct!izObserverInterconnector;
        auto isubj = construct!intPropSubject;
        auto iobs1 = construct!foo;
        auto iobs2 = construct!foo;
        auto iobs3 = construct!foo;
        auto usubj = construct!uintPropSubject;
        auto uobs1 = construct!bar;
        auto uobs2 = construct!bar;
        auto uobs3 = construct!bar;

        scope(exit)
        {
            destruct(inter, isubj, usubj);
            destruct(iobs1, iobs2, iobs3);
            destruct(uobs1, uobs2, uobs3);
            destruct(nots1, nots2);
        }
            
        inter.beginUpdate;
        // add valid entities
        inter.addSubjects(isubj, usubj);
        inter.addObservers(iobs1, iobs2, iobs3);
        inter.addObservers(uobs1, uobs2, uobs3);
        // add invalid entities
        inter.addSubjects(nots1, nots2);
        inter.addObservers(nots1, nots2);
        // not added twice
        inter.addSubjects(isubj, usubj);
        inter.endUpdate;

        // check the subject and observers count
        assert(inter.fSubjects.count == 2);
        assert(inter.fObservers.count == 8);
        assert(isubj.fObservers.count == 3);
        assert(usubj.fObservers.count == 3);

        inter.beginUpdate;
        inter.removeObserver(iobs1);
        inter.endUpdate;

        assert(inter.fSubjects.count == 2);
        assert(inter.fObservers.count == 7);
        assert(isubj.fObservers.count == 2);
        assert(usubj.fObservers.count == 3);
        
        // update subject
        isubj._min = -127;
        isubj._max = 128;
        isubj.updateObservers;    
        // iobs1 has been removed
        assert(iobs1._min != -127);
        assert(iobs1._max != 128);
        // check observers
        assert(iobs2._min == -127);
        assert(iobs2._max == 128);
        assert(iobs3._min == -127);
        assert(iobs3._max == 128);
        
        // update subject
        usubj._min = 2;
        usubj._max = 256;
        usubj.updateObservers;
        // check observers
        assert(uobs1._min == 2);
        assert(uobs1._max == 256);
        assert(uobs2._min == 2);
        assert(uobs2._max == 256);
        assert(uobs3._min == 2);
        assert(uobs3._max == 256);        

        import std.stdio;
        writeln( "izObserverInterconnector passed the tests");
    }
}


/**
 * interface for an observer based on an enum.
 * Params:
 * E = an enum.
 * T = variadic type of the parameters an observer monitors.
 */
interface izEnumBasedObserver(E, T...)
if (is(E == enum))
{
    /**
     * The method called by a subject.
     * Params:
     * notification = the E member allowing to distinguish the "call reason".
     * t = the parameters the observer is interested in.
     */
    void subjectNotification(E notification, T t);   
}

/**
 * izCustomSubject handles a list of obsever.
 * This version only accept an observer if it's an izEnumBasedObserver.
 * Params:
 * E = an enum.
 * T = the variadic list of parameter types used in the notification. 
 */
class izCustomSubject(E, T...) : izSubject 
if (is(E == enum))
{
    protected
    {
        alias ObserverType = izEnumBasedObserver!(E,T);
        izDynamicList!ObserverType fObservers;
    }
    public
    {
        this()
        {
            fObservers = construct!(izDynamicList!ObserverType);
        }

        ~this()
        {
            fObservers.destruct;
        }

        void updateObservers()
        {
            /*virtual: send all values*/
        }

        bool acceptObserver(Object anObserver)
        {
            return (cast(ObserverType) anObserver !is null);
        }

        void addObserver(Object anObserver)
        {
            auto obs = cast(ObserverType) anObserver;
            if (!obs)
                return;
            if (fObservers.find(obs) != -1)
                return;
            fObservers.add(obs);
        }

        void addObservers(Objs...)(Objs objs)
        {
            foreach(obj; objs)
                addObserver(obj);
        }

        void removeObserver(Object anObserver)
        {
            auto obs = cast(ObserverType) anObserver;
            if (!obs)
                return;
            fObservers.remove(obs);
        }
    }
} 

unittest
{
    enum DocumentNotification{opening, closing, saving, changed}
    
    class Document {}
    class Highlighter {}
    
    class DocSubject : izCustomSubject!(DocumentNotification, Document, Highlighter)
    {
        void notify(DocumentNotification dn)
        {
            foreach(obs;fObservers)
                (cast(ObserverType) obs)
                    .subjectNotification(dn, null, null);
        }
    }
    class DocObserver: izEnumBasedObserver!(DocumentNotification, Document, Highlighter)
    {
        DocumentNotification lastNotification;
        void subjectNotification(DocumentNotification notification, Document doc, Highlighter hl)
        {
            lastNotification = notification;
        }
    }   
    
    auto inter = construct!izObserverInterconnector;
    auto subj = construct!DocSubject;
    auto obs1 = construct!DocObserver;
    auto obs2 = construct!DocObserver;
    auto obs3 = construct!DocObserver;
    
    scope(exit) destruct(inter, subj, obs1, obs2, obs3);
    
    inter.addSubject(subj);
    inter.addObservers(obs1, obs2, obs3);
    inter.addObservers(obs1, obs2, obs3);
    assert(inter.fObservers.count == 3);
    assert(subj.fObservers.count == 3);
    
    subj.notify(DocumentNotification.changed);
    assert(obs1.lastNotification == DocumentNotification.changed);
    assert(obs2.lastNotification == DocumentNotification.changed);
    assert(obs3.lastNotification == DocumentNotification.changed);
    subj.notify(DocumentNotification.opening);
    assert(obs1.lastNotification == DocumentNotification.opening);
    assert(obs2.lastNotification == DocumentNotification.opening);
    assert(obs3.lastNotification == DocumentNotification.opening);
    
    import std.stdio;
    writeln( "izEnumBasedObserver passed the tests");       
}
