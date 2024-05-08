#pragma once

#include "metadata/metadatamanager.hpp"
#include "plan/updateplanner.hpp"

namespace simpledb {
class index_update_planner : public update_planner {
public:
  index_update_planner(metadata_manager *pMM);
  int execute_insert(insert_data *pID, transaction *pTx) override;
  int execute_delete(delete_data *pDD, transaction *pTx) override;
  int execute_modify(modify_data *pMD, transaction *pTx) override;
  int execute_create_table(create_table_data *pCTD, transaction *pTx) override;
  int execute_create_view(create_view_data *pCVD, transaction *pTx) override;
  int execute_create_index(create_index_data *pCID, transaction *pTx) override;

private:
  metadata_manager *mMM;
};
} // namespace simpledb
