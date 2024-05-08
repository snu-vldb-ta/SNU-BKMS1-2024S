#include "plan/productplan.hpp"
#include "query/productscan.hpp"

namespace simpledb {
product_plan::product_plan(const std::shared_ptr<plan> &pP1,
                           const std::shared_ptr<plan> &pP2)
    : mP1(pP1), mP2(pP2) {
  mSch.add_all(mP1->get_schema());
  mSch.add_all(mP2->get_schema());
}

std::shared_ptr<scan> product_plan::open() {
  std::shared_ptr<scan> s1 = mP1->open();
  std::shared_ptr<scan> s2 = mP2->open();
  return std::static_pointer_cast<scan>(std::make_shared<product_scan>(s1, s2));
}

int product_plan::blocks_accessed() {
  return mP1->blocks_accessed() +
         mP1->records_output() * mP2->blocks_accessed();
}

int product_plan::records_output() {
  return mP1->records_output() * mP2->records_output();
}

int product_plan::distinct_values(const std::string &pFldName) {
  if (mP1->get_schema().has_field(pFldName)) {
    return mP1->distinct_values(pFldName);
  } else {
    return mP2->distinct_values(pFldName);
  }
}

schema product_plan::get_schema() { return mSch; }
} // namespace simpledb
