module iz.observer;

import std.stdio;
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
    /// an observer want to be removed.
    void removeObserver(Object anObserver);
    /// sends all data the observers are monitoring.
    void updateObservers();
}

/**
 * izCustomSubject handles a list of Obsevers of Types OT.
 * even if both types are filtered, OT should rather be an interface than a class.
 */
class izCustomSubject(OT): izObject, izSubject
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
            fObservers = molish!(izDynamicList!OT);
        }

        ~this()
        {
            fObservers.demolish;
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
            auto obs = cast(OT) anObserver;
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
            if (!acceptObserver(anObserver))
                return;
            auto obs = cast(OT) anObserver;
            fObservers.remove(obs);
        }
    }
}

/**
 * izObserverInterconnector is in charge for inter-connecting
 * some subjects with their observers, whatever their specializations are.
 */
class izObserverInterconnector: izSubject
{
    private
    {
        izDynamicList!Object fObservers;
        izDynamicList!Object fSubjects;
        bool fUpdating;
    }
    public
    {
        this()
        {
            fObservers = molish!(izDynamicList!Object);
            fSubjects = molish!(izDynamicList!Object);
        }

        ~this()
        {
            fObservers.demolish;
            fSubjects.demolish;
        }

        bool acceptObserver(Object anObserver)
        {
            // here the specialization doesn't matter.
            // izSubject is in the inheritence list because its methods partially match.
            return true;
        }

        /// some subjects or some observers will be added.
        void beginUpdate()
        {
            fUpdating = true;
        }

        /// some subjects or some observers have been added.
        void endUpdate()
        {
            updateAll;
        }

        void addObserver(Object anObserver)
        {
            if (!acceptObserver(anObserver))
                return;
            if (fObservers.find(anObserver) != -1)
                return;
            beginUpdate;
            fObservers.add(anObserver);
        }

        void addObservers(Objs...)(Objs objs)
        {
            foreach(obj; objs)
                addObserver(obj);
        }

        void removeObserver(Object anObserver)
        {
            beginUpdate;
            fObservers.remove(anObserver);
            for (auto i = 0; i < fSubjects.count; i++)
                (cast(izSubject) fSubjects[i]).removeObserver(anObserver);
        }

        void addSubject(Object aSubject)
        {
            beginUpdate;
            if (fSubjects.find(aSubject) != -1)
                return;
            fSubjects.add(aSubject);
        }

        void addSubjects(Subjs...)(Subjs subjs)
        {
            foreach(subj; subjs)
                addSubject(subj);
        }

        void removeSubject(Object aSubject)
        {
            beginUpdate;
            fSubjects.remove(aSubject);
        }

        /**
         * updates the connections. Usually has not be called manually.
         */
        void updateObservers()
        {
            fUpdating = false;
            for(auto subjectIx = 0; subjectIx < fSubjects.count; subjectIx++)
            {
                auto subject = cast(izSubject) fSubjects[subjectIx];
                if (!subject)
                    continue;

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
        void min(int aValue){writeln("min");}
        void max(int aValue){writeln("max");}
        void def(int aValue){writeln("def");}
    }
    alias uintPropObserver = PropObserver!uint;

    class bar: uintPropObserver
    {
        void min(uint aValue){writeln("min");}
        void max(uint aValue){writeln("max");}
        void def(uint aValue){writeln("def");}
    }

    class intPropSubject : izCustomSubject!intPropObserver
    {
        final override void updateObservers()
        {
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).min(int.min);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).max(int.max);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).def(int.init);
        }
    }

    class uintPropSubject : izCustomSubject!uintPropObserver
    {
        final override void updateObservers()
        {
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).min(uint.min);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).max(uint.max);
            for(auto i = 0; i < fObservers.count; i++)
                (cast(intPropObserver)fObservers[i]).def(uint.init);
        }
    }

    unittest
    {
        auto inter = molish!izObserverInterconnector;
        auto isubj = molish!intPropSubject;
        auto iobs1 = molish!foo;
        auto iobs2 = molish!foo;
        auto iobs3 = molish!foo;
        auto usubj = molish!uintPropSubject;
        auto uobs1 = molish!bar;
        auto uobs2 = molish!bar;
        auto uobs3 = molish!bar;

        scope(exit)
        {
            demolish(inter, isubj, usubj);
            demolish(iobs1, iobs2, iobs3);
            demolish(uobs1, uobs2, uobs3);
        }

        inter.beginUpdate;
        inter.addSubjects(isubj, usubj);
        inter.addObservers(iobs1, iobs2, iobs3);
        inter.addObservers(uobs1, uobs2, uobs3);
        inter.endUpdate;

        assert(inter.fSubjects.count == 2);
        assert(inter.fObservers.count == 6);
        assert(isubj.fObservers.count == 3);
        assert(usubj.fObservers.count == 3);

        inter.beginUpdate;
        inter.removeObserver(iobs1);
        inter.endUpdate;

        assert(inter.fSubjects.count == 2);
        assert(inter.fObservers.count == 5);
        assert(isubj.fObservers.count == 2);
        assert(usubj.fObservers.count == 3);

        writeln( "izObserverInterconnector passed the tests");
    }
}
