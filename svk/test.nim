import ./api

var vk = svkCreateInstance("test")
echo vk
var pdev: SVkPhysicalDevice
for d in vk.getUsablePhysicalDevices():
  echo d.name, " queue familye: ", d.queueFamily
  echo "memory types:"
  for mt in d.memoryTypes:
    echo "  ", mt
  echo ""
  pdev = d
  if d.discreteGPU:
    break

var dev = vk.svkCreateDevice(pdev)

dev.destroy()
vk.destroy()
