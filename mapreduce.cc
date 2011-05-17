#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/var.h>
#include <cstdio>
#include <string>
#include <sstream>
#include <pthread.h>
#include <stdlib.h>
#include <limits.h>

/// These are the method names as JavaScript sees them.  Add any methods for
/// your class here.

#define NUM_THREADS 1

namespace {

	template <typename T>
	inline std::string toString(const T& t) {
		std::stringstream ss;
		ss << t;
		return ss.str();
	}

    int counter = 0;
	int multicounter = 0;
	int thread_counter[10];

	const char* const kHelloWorldMethodId = "HelloWorld";
	const char* const kSetCounterMethodId = "SetCounter";
	const char* const kLaunchThreadMethodId = "LaunchThread";
	const char* const kReadMultiCounterMethodId = "ReadMultiCounter";
	
	std::string HelloWorld() {
	    counter++;
		return "Hello from Native Client! You've called this function " + toString(counter) + " time(s).";
	}
	
	void* ChildThread(void * x) {
		int tid = (int)x;
	    counter++;
	    while(multicounter < INT_MAX) {
			multicounter++;
			thread_counter[tid]++;
			usleep(100);
		}
		return NULL;
	}
	
	std::string LaunchThread() {
		pthread_t thread_tcb[10];
		pthread_attr_t pthread_custom_attr;
		pthread_attr_init(&pthread_custom_attr);
		
		for(int i = 0; i < 10; ++i)
			pthread_create(&thread_tcb[i], &pthread_custom_attr, ChildThread, (int *)i);
			
		/*for(int i = 0; i < 10; ++i)
			pthread_join(thread_tcb[i], NULL);*/
		
		return "Launched threads";
	}

	std::string ReadMultiCounter() {
		std::string rt = "";
		int sum = 0;
		rt += "multicounter = " + toString(multicounter);
		for(int i = 0; i < 10; ++i) {
			rt += "<br>tc[" + toString(i) + "] = " + toString(thread_counter[i]);
			sum += thread_counter[i];
		}
		rt += "<br>sum = " + toString(sum);
		rt += "<br>";
		return rt;
	}
	
	std::string SetCounter(const pp::Var& x) {
		if(!x.is_number()) return "Invalid";
		counter = x.is_int() ? x.AsInt() : static_cast<int32_t>(x.AsDouble());
		return "Counter is now " + toString(counter);
	}

}

class MapreduceScriptableObject : public pp::deprecated::ScriptableObject {
 public:

  virtual bool HasMethod(const pp::Var& method, pp::Var* exception);

  virtual pp::Var Call(const pp::Var& method,
                       const std::vector<pp::Var>& args,
                       pp::Var* exception);
                       
};

bool MapreduceScriptableObject::HasMethod(const pp::Var& method,
                                                pp::Var* exception) {
  if (!method.is_string()) {
    return false;
  }
  std::string method_name = method.AsString();

  if(method_name == kHelloWorldMethodId) {
  	return true;
  } else if(method_name == kSetCounterMethodId) {
  	return true;
  } else if(method_name == kLaunchThreadMethodId) {
  	return true;
  } else if(method_name == kReadMultiCounterMethodId) {
  	return true;
  }
  
  return false;
}

pp::Var MapreduceScriptableObject::Call(const pp::Var& method,
                                        const std::vector<pp::Var>& args,
                                        pp::Var* exception) {
  if (!method.is_string()) {
    return pp::Var();
  }
  std::string method_name = method.AsString();

  if(method_name == kHelloWorldMethodId) {
  	return pp::Var(HelloWorld());
  } else if(method_name == kSetCounterMethodId) {
  	return pp::Var(SetCounter(args[0]));
  } else if(method_name == kLaunchThreadMethodId) {
  	return pp::Var(LaunchThread());
  } else if(method_name == kReadMultiCounterMethodId) {
  	return pp::Var(ReadMultiCounter());
  }

  return pp::Var();
}


class MapreduceInstance : public pp::Instance {
 public:
  explicit MapreduceInstance(PP_Instance instance) : pp::Instance(instance) {}
  virtual ~MapreduceInstance() {}

  virtual pp::Var GetInstanceObject() {
    MapreduceScriptableObject* hw_object = new MapreduceScriptableObject();
    return pp::Var(this, hw_object);
  }
};

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of your NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with type="application/x-nacl".
class MapreduceModule : public pp::Module {
 public:
  MapreduceModule() : pp::Module() {}
  virtual ~MapreduceModule() {}

  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new MapreduceInstance(instance);
  }
};

namespace pp {

   Module* CreateModule() {
  	 return new MapreduceModule();
   }
   
}  // namespace pp
