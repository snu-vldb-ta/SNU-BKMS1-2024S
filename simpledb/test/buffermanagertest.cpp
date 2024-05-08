#include <iostream>

#include "buffer/buffermanager.hpp"
#include "file/blockid.hpp"
#include "file/filemanager.hpp"
#include "file/page.hpp"
#include "server/simpledb.hpp"
#include "gtest/gtest.h"

namespace simpledb {
TEST(buffer, buffermanager_test) {
  simpledb db("buffermgrtest", 400, 3, "vanilla"); // three buffers, type: "vanilla", "lru"
  buffer_manager &bM = db.buffer_mgr();

  std::vector<buffer *> buff(6); //test buffers 
  std::string testFile = "testfile";
  buff[0] = bM.pin(block_id(testFile, 0));
  buff[1] = bM.pin(block_id(testFile, 1));
  buff[2] = bM.pin(block_id(testFile, 2));

  bM.unpin(buff[1]);
  buff[1] = nullptr;

  buff[3] = bM.pin(block_id(testFile, 0));
  buff[4] = bM.pin(block_id(testFile, 1));
  std::cout << "Available buffers " << bM.available() << std::endl;
  try {
    std::cout << "Attempting to pin block 3" << std::endl;
    buff[5] = bM.pin(block_id(testFile, 3));
  } catch (std::exception &e) {
    std::cout << e.what() << std::endl;
  }

  bM.unpin(buff[2]);
  buff[2] = nullptr;
  buff[5] = bM.pin(block_id(testFile, 3));
  
  bM.print_status();
}
} // namespace simpledb
