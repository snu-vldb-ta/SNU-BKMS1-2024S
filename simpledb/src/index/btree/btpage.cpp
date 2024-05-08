#include "index/btree/btpage.hpp"

namespace simpledb {
bt_page::bt_page(transaction *pTx, const block_id &pCurrentBlk,
                 const layout &pLt)
    : mTx(pTx), mCurrentBlk(pCurrentBlk), mLt(pLt) {
  mTx->pin(mCurrentBlk);
}

int bt_page::find_slot_before(const constant &pSearchKey) {
  int slot = 0;
  while (slot < get_num_recs() && get_data_val(slot) < pSearchKey) {
    slot++;
  }
  return slot - 1;
}

void bt_page::close() {
  if (!mCurrentBlk.is_null()) {
    mTx->unpin(mCurrentBlk);
  }
  mCurrentBlk = block_id();
}

bool bt_page::is_full() {
  return slot_pos(get_num_recs() + 1) >= mTx->block_size();
}

block_id bt_page::split(int pSplitPos, int pFlag) {
  block_id newBlk = append_new(pFlag);
  bt_page newPage(mTx, newBlk, mLt);
  transfer_recs(pSplitPos, &newPage);
  newPage.set_flag(pFlag);
  newPage.close();
  return newBlk;
}

constant bt_page::get_data_val(int pSlot) { return get_val(pSlot, "dataval"); }

int bt_page::get_flag() { return mTx->get_int(mCurrentBlk, 0); }

void bt_page::set_flag(int pVal) { mTx->set_int(mCurrentBlk, 0, pVal, true); }

block_id bt_page::append_new(int pFlag) {
  block_id blk = mTx->append(mCurrentBlk.file_name());
  mTx->pin(blk);
  format(blk, pFlag);
  return blk;
}

void bt_page::format(const block_id &pBlk, int pFlag) {
  mTx->set_int(pBlk, 0, pFlag, false);
  mTx->set_int(pBlk, sizeof(int), 0, false); // #records = 0
  int recSize = mLt.slot_size();
  for (int pos = 2 * sizeof(int); pos + recSize <= mTx->block_size();
       pos += recSize) {
    make_default_record(pBlk, pos);
  }
}

void bt_page::make_default_record(const block_id &pBlk, int pPos) {
  for (const std::string &pFldName : mLt.get_schema().fields()) {
    int offset = mLt.offset(pFldName);
    if (mLt.get_schema().type(pFldName) == schema::integer) {
      mTx->set_int(pBlk, pPos + offset, 0, false);
    } else {
      mTx->set_string(pBlk, pPos + offset, "", false);
    }
  }
}

// methods called only by btree dir
int bt_page::get_child_num(int pSlot) { return get_int(pSlot, "block"); }

void bt_page::insert_dir(int pSlot, const constant &pVal, int pBlkNum) {
  insert(pSlot);
  set_val(pSlot, "dataval", pVal);
  set_int(pSlot, "block", pBlkNum);
}

// methods called only by btree leaf
rid bt_page::get_data_rid(int pSlot) {
  return rid(get_int(pSlot, "block"), get_int(pSlot, "id"));
}

void bt_page::insert_leaf(int pSlot, const constant &pVal, const rid &pRid) {
  insert(pSlot);
  set_val(pSlot, "dataval", pVal);
  set_int(pSlot, "block", pRid.block_number());
  set_int(pSlot, "id", pRid.slot());
}

void bt_page::remove(int pSlot) {
  for (int i = pSlot + 1; i < get_num_recs(); i++) {
    copy_record(i, i - 1);
  }
  set_num_recs(get_num_recs() - 1);
  return;
}

int bt_page::get_num_recs() { return mTx->get_int(mCurrentBlk, sizeof(int)); }

// private methods
int bt_page::get_int(int pSlot, const std::string &pFldName) {
  int pos = fld_pos(pSlot, pFldName);
  return mTx->get_int(mCurrentBlk, pos);
}

std::string bt_page::get_string(int pSlot, const std::string &pFldName) {
  int pos = fld_pos(pSlot, pFldName);
  return mTx->get_string(mCurrentBlk, pos);
}

constant bt_page::get_val(int pSlot, const std::string &pFldName) {
  int type = mLt.get_schema().type(pFldName);
  if (type == schema::integer) {
    return constant(get_int(pSlot, pFldName));
  } else {
    return constant(get_string(pSlot, pFldName));
  }
}

void bt_page::set_int(int pSlot, const std::string &pFldName, int pVal) {
  int pos = fld_pos(pSlot, pFldName);
  mTx->set_int(mCurrentBlk, pos, pVal, true);
}

void bt_page::set_string(int pSlot, const std::string &pFldName,
                         const std::string &pVal) {
  int pos = fld_pos(pSlot, pFldName);
  mTx->set_string(mCurrentBlk, pos, pVal, true);
}

void bt_page::set_val(int pSlot, const std::string &pFldName,
                      const constant &pVal) {
  int type = mLt.get_schema().type(pFldName);
  if (type == schema::integer) {
    set_int(pSlot, pFldName, pVal.as_int());
  } else {
    set_string(pSlot, pFldName, pVal.as_string());
  }
}

void bt_page::set_num_recs(int pN) {
  mTx->set_int(mCurrentBlk, sizeof(int), pN, true);
}

void bt_page::insert(int pSlot) {
  for (int i = get_num_recs(); i > pSlot; i--) {
    copy_record(i - 1, i);
  }
  set_num_recs(get_num_recs() + 1);
}

void bt_page::copy_record(int pFrom, int pTo) {
  schema sch(mLt.get_schema());
  for (const std::string &fldName : sch.fields()) {
    set_val(pTo, fldName, get_val(pFrom, fldName));
  }
}

void bt_page::transfer_recs(int pSlot, bt_page *pDest) {
  int destSlot = 0;
  while (pSlot < get_num_recs()) {
    pDest->insert(destSlot);
    schema sch(mLt.get_schema());
    for (const std::string &fldName : sch.fields()) {
      pDest->set_val(destSlot, fldName, get_val(pSlot, fldName));
      remove(pSlot);
      destSlot++;
    }
  }
}

int bt_page::fld_pos(int pSlot, const std::string &pFldName) {
  int offset = mLt.offset(pFldName);
  return slot_pos(pSlot) + offset;
}

int bt_page::slot_pos(int pSlot) {
  int slotSize = mLt.slot_size();
  return sizeof(int) + sizeof(int) + (pSlot * slotSize);
}

} // namespace simpledb
