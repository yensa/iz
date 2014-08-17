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
 * izCustomSubject handles a list of obsevers of types OT.
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

        void removeObserver(Object anObserver)
        {
            beginUpdate;
            fObservers.remove(anObserver);
        }

        void addSubject(Object aSubject)
        {
            beginUpdate;
            if (fSubjects.find(aSubject) != -1)
                return;
            fSubjects.add(aSubject);
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

    interface intPropObserver
    {
        void min(int aValue);
        void max(int aValue);
        void def(int aValue);
    }

    class foo: intPropObserver
    {
        void min(int aValue){writeln("min");}
        void max(int aValue){writeln("max");}
        void def(int aValue){writeln("def");}
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

    unittest
    {
        auto inter = molish!izObserverInterconnector;
        auto subj = molish!intPropSubject;
        auto obs1 = molish!foo;
        auto obs2 = molish!foo;
        auto obs3 = molish!foo;

        scope(exit)
        {
            inter.demolish;
            subj.demolish;
            obs1.demolish;
            obs2.demolish;
            obs3.demolish;
        }

        inter.beginUpdate;
        inter.addObserver(obs1);
        inter.addObserver(obs2);
        inter.addObserver(obs3);
        inter.addSubject(subj);
        inter.endUpdate;

        assert(inter.fSubjects.count == 1);
        assert(inter.fObservers.count == 3);
        assert(subj.fObservers.count == 3);

        writeln( "izObserverInterconnector passed the tests");
    }

}
