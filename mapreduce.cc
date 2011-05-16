#include <ppapi/cpp/dev/scriptable_object_deprecated.h>
#include <ppapi/cpp/instance.h>
#include <ppapi/cpp/module.h>
#include <ppapi/cpp/var.h>
#include <cstdio>
#include <string>
#include <sstream>

/// These are the method names as JavaScript sees them.  Add any methods for
/// your class here.
namespace {

	template <typename T>
	inline std::string toString(const T& t) {
		std::stringstream ss;
		ss << t;
		return ss.str();
	}

    int counter = 0;

	const char* const kHelloWorldMethodId = "HelloWorld";
	
	std::string HelloWorld() {
	    counter++;
		return "Hello from Native Client! You've called this function " + toString(counter) + " time(s).";
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
  } else {
  	return false;
  }
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
