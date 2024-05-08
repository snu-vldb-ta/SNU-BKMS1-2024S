#include <chrono>
#include <stdexcept>
#include <iostream>

#include "buffer/buffermanager.hpp"

namespace simpledb {
buffer::buffer(file_manager *pFileManager, log_manager *pLogManager)
    : mFileManager(pFileManager), mLogManager(pLogManager) {
  mContents = std::make_unique<page>(mFileManager->block_size());
}

page *buffer::contents() const { return mContents.get(); }

block_id buffer::block() const { return mBlockId; }

void buffer::set_modified(int pTxNum, int pLSN) {
  mTxNum = pTxNum;
  if (pLSN >= 0)
    mLSN = pLSN;
}

bool buffer::is_pinned() const { return mPins > 0; }

int buffer::modifying_tx() const { return mTxNum; }

void buffer::assign_to_block(const block_id &pBlockId) {
  flush();
  mBlockId = pBlockId;
  mFileManager->read(mBlockId, *mContents);
  mPins = 0;
}

void buffer::flush() {
  if (mTxNum >= 0) {
    mLogManager->flush(mLSN);
    mFileManager->write(mBlockId, *mContents);
    mTxNum = -1;
  }
}

void buffer::pin() { mPins++; }

void buffer::unpin() { mPins--; }


// vanilla_buffer_manager
vanilla_buffer_manager::vanilla_buffer_manager(file_manager *pFileManager,
                               log_manager *pLogManager, int pNumBuffs) {
  mNumAvailable = pNumBuffs;
  for (int i = 0; i < pNumBuffs; i++) {
    auto bufferPtr = std::make_unique<buffer>(pFileManager, pLogManager);
    mBufferPool.emplace_back(std::move(bufferPtr));
  }
}

int vanilla_buffer_manager::available() {
  std::unique_lock<std::mutex> lock(mMutex);
  return mNumAvailable;
}

void vanilla_buffer_manager::flush_all(int pTxNum) {
  std::unique_lock<std::mutex> lock(mMutex);
  for (auto &&buff : mBufferPool) {
    if (buff->modifying_tx() == pTxNum) {
      buff->flush();
    }
  }
}

void vanilla_buffer_manager::unpin(buffer *pBuff) {
  std::unique_lock<std::mutex> lock(mMutex);
  pBuff->unpin();
  if (!pBuff->is_pinned()) {
    mNumAvailable++;
    mCondVar.notify_all();
  }
}

buffer *vanilla_buffer_manager::pin(const block_id &pBlockId) {
  std::unique_lock<std::mutex> lock(mMutex);
  auto start = std::chrono::high_resolution_clock::now();
  buffer *buff = try_to_pin(pBlockId);
  // while buffer is null and not have waited too long
  while (!buff && !waiting_too_long(start)) {
    mCondVar.wait_for(lock, std::chrono::milliseconds(mMaxTime));
  }
  if (!buff) {
    throw std::runtime_error("buffer abort exception");
  }
  return buff;
}

bool vanilla_buffer_manager::waiting_too_long(
    std::chrono::time_point<std::chrono::high_resolution_clock> pStartTime) {
  auto end = std::chrono::high_resolution_clock::now();
  double elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(end - pStartTime)
          .count();
  return elapsed > mMaxTime;
}

buffer *vanilla_buffer_manager::try_to_pin(const block_id &pBlockId) {
  buffer *buff = find_existing_buffer(pBlockId);
  // if buffer is not found
  if (!buff) {
    buff = choose_unpinned_buffer();
    if (!buff) {
      return buff;
    }
    buff->assign_to_block(pBlockId);
  }
  // if buffer is not pinned
  if (!buff->is_pinned()) {
    mNumAvailable--;
  }
  buff->pin();
  return buff;
}

buffer *vanilla_buffer_manager::find_existing_buffer(const block_id &pBlockId) {
  for (auto &&buff : mBufferPool) {
    block_id blockId = buff->block();
    if (!blockId.is_null() && blockId == pBlockId) {
      return buff.get();
    }
  }
  return nullptr;
}

buffer *vanilla_buffer_manager::choose_unpinned_buffer() {
  for (auto &&buff : mBufferPool) {
    if (!buff->is_pinned()) {
      return buff.get();
    }
  }
  return nullptr;
}

float vanilla_buffer_manager::get_hit_ratio() {
  //implement your own code
  return 0.00;
}

void vanilla_buffer_manager::print_status(){
  //implement your own code
}


// lru_buffer_manager
lru_buffer_manager::lru_buffer_manager(file_manager *pFileManager,
                               log_manager *pLogManager, int pNumBuffs) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  mNumAvailable = pNumBuffs;
  for (int i = 0; i < pNumBuffs; i++) {
    auto bufferPtr = std::make_unique<buffer>(pFileManager, pLogManager);
    mBufferPool.emplace_back(std::move(bufferPtr));
  }
}

int lru_buffer_manager::available() {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  std::unique_lock<std::mutex> lock(mMutex);
  return mNumAvailable;
}

void lru_buffer_manager::flush_all(int pTxNum) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  std::unique_lock<std::mutex> lock(mMutex);
  for (auto &&buff : mBufferPool) {
    if (buff->modifying_tx() == pTxNum) {
      buff->flush();
    }
  }
}

void lru_buffer_manager::unpin(buffer *pBuff) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  std::unique_lock<std::mutex> lock(mMutex);
  pBuff->unpin();
  if (!pBuff->is_pinned()) {
    mNumAvailable++;
    mCondVar.notify_all();
  }
}

buffer *lru_buffer_manager::pin(const block_id &pBlockId) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  std::unique_lock<std::mutex> lock(mMutex);
  auto start = std::chrono::high_resolution_clock::now();
  buffer *buff = try_to_pin(pBlockId);
  // while buffer is null and not have waited too long
  while (!buff && !waiting_too_long(start)) {
    mCondVar.wait_for(lock, std::chrono::milliseconds(mMaxTime));
  }
  if (!buff) {
    throw std::runtime_error("buffer abort exception");
  }
  return buff;
}

bool lru_buffer_manager::waiting_too_long(
    std::chrono::time_point<std::chrono::high_resolution_clock> pStartTime) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  auto end = std::chrono::high_resolution_clock::now();
  double elapsed =
      std::chrono::duration_cast<std::chrono::milliseconds>(end - pStartTime)
          .count();
  return elapsed > mMaxTime;
}

buffer *lru_buffer_manager::try_to_pin(const block_id &pBlockId) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  buffer *buff = find_existing_buffer(pBlockId);
  // if buffer is not found
  if (!buff) {
    buff = choose_unpinned_buffer();
    if (!buff) {
      return buff;
    }
    buff->assign_to_block(pBlockId);
  }
  // if buffer is not pinned
  if (!buff->is_pinned()) {
    mNumAvailable--;
  }
  buff->pin();
  return buff;
}

buffer *lru_buffer_manager::find_existing_buffer(const block_id &pBlockId) {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  for (auto &&buff : mBufferPool) {
    block_id blockId = buff->block();
    if (!blockId.is_null() && blockId == pBlockId) {
      return buff.get();
    }
  }
  return nullptr;
}

buffer *lru_buffer_manager::choose_unpinned_buffer() {
  //////////////VANILLA VERSION ////////////////////
  ///////////CHANGE THE CODE BELOW /////////////////
  for (auto &&buff : mBufferPool) {
    if (!buff->is_pinned()) {
      return buff.get();
    }
  }
  return nullptr;
}

float lru_buffer_manager::get_hit_ratio() {
  //implement your own code
  return 0.00;
}

void lru_buffer_manager::print_status(){
  //implement your own code
}


} // namespace simpledb
