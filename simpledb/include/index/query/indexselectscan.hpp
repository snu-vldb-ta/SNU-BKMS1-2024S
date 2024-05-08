#pragma once

#include <memory>
#include <string>

#include "index/index.hpp"
#include "query/constant.hpp"
#include "record/tablescan.hpp"

namespace simpledb {
class index_select_scan : public scan {
public:
  index_select_scan(const std::shared_ptr<table_scan> &pTS,
                    const std::shared_ptr<index> &pIdx, const constant &pVal);
  void before_first() override;
  bool next() override;
  int get_int(const std::string &pFldName) override;
  std::string get_string(const std::string &pFldName) override;
  constant get_val(const std::string &pFldName) override;
  bool has_field(const std::string &pFldName) override;
  void close() override;

private:
  std::shared_ptr<table_scan> mTS;
  std::shared_ptr<index> mIdx;
  constant mVal;
};
} // namespace simpledb
