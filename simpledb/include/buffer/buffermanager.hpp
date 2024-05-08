#pragma once

#include <condition_variable>
#include <memory>
#include <mutex>
#include <iostream>

#include "file/filemanager.hpp"
#include "log/logmanager.hpp"

namespace simpledb {
class buffer {
public:
  buffer(file_manager *pFileManager, log_manager *pLogManager);
  page *contents() const;
  block_id block() const;
  void set_modified(int pTxNum, int pLSN);
  bool is_pinned() const;
  int modifying_tx() const;
  void assign_to_block(const block_id &pBlockId);
  void flush();
  void pin();
  void unpin();

private:
  file_manager *mFileManager;
  log_manager *mLogManager;
  std::unique_ptr<page> mContents;
  block_id mBlockId;
  int mPins = 0;
  int mTxNum = -1; // transaction that touched the buffer last
  int mLSN = -1;
};

class buffer_manager {
  public: 
  virtual ~buffer_manager() {}
  virtual int available() = 0;
  virtual void flush_all(int pTxNum) = 0;
  virtual void unpin(buffer *pBuff) = 0;
  virtual buffer *pin(const block_id &pBlockId) = 0;
  virtual float get_hit_ratio() = 0;
  virtual void print_status() = 0;

};

class vanilla_buffer_manager: public buffer_manager {
  public:
    vanilla_buffer_manager(file_manager *pFileManager, log_manager *pLogManager,
                    int pNumBuffs);
    // ~vanilla_buffer_manager() ;
    int available() override;
    void flush_all(int pTxNum) override;
    void unpin(buffer *pBuff) override;
    buffer *pin(const block_id &pBlockId) override;
    float get_hit_ratio() override;
    void print_status() override;

  private:
  std::vector<std::unique_ptr<buffer>> mBufferPool;
  int mNumAvailable; // number of unpinned buffers
  const int mMaxTime = 10000;
  std::mutex mMutex;
  std::condition_variable mCondVar;

  bool waiting_too_long(
      std::chrono::time_point<std::chrono::high_resolution_clock> pStartTime);
  buffer *try_to_pin(const block_id &pBlockId);
  buffer *find_existing_buffer(const block_id &pBlockId);
  buffer *choose_unpinned_buffer();
};

class lru_buffer_manager: public buffer_manager {
  public:
    lru_buffer_manager(file_manager *pFileManager, log_manager *pLogManager,
                    int pNumBuffs);
    // ~lru_buffer_manager();
    int available() override;
    void flush_all(int pTxNum) override;
    void unpin(buffer *pBuff) override;
    buffer *pin(const block_id &pBlockId) override;
    float get_hit_ratio() override;
    void print_status() override;
  
  private:
    std::vector<std::unique_ptr<buffer>> mBufferPool;
    int mNumAvailable; // number of unpinned buffers
    const int mMaxTime = 10000;
    std::mutex mMutex;
    std::condition_variable mCondVar;

    bool waiting_too_long(
        std::chrono::time_point<std::chrono::high_resolution_clock> pStartTime);
    buffer *try_to_pin(const block_id &pBlockId);
    buffer *find_existing_buffer(const block_id &pBlockId);
    buffer *choose_unpinned_buffer();

};


} // namespace simpledb
