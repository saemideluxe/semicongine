import ./api

var vk = svkCreateInstance("test")
echo vk
for d in vk.getUsablePhysicalDevices():
  echo d.name, " queue familye: ", d.queueFamily
  echo "memory types:"
  for mt in d.memoryTypes:
    echo "  ", mt
  echo ""

vk.destroy()
