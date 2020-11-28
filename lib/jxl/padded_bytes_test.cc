// Copyright (c) the JPEG XL Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "lib/jxl/base/padded_bytes.h"

#include <numeric>  // iota
#include <vector>
#include "gtest/gtest.h"

namespace jxl {
namespace {

TEST(PaddedBytesTest, TestNonEmptyFirstByteZero) {
  PaddedBytes pb(1);
  EXPECT_EQ(0, pb[0]);
  // Even after resizing..
  pb.resize(20);
  EXPECT_EQ(0, pb[0]);
  // And reserving.
  pb.reserve(200);
  EXPECT_EQ(0, pb[0]);
}

TEST(PaddedBytesTest, TestEmptyFirstByteZero) {
  PaddedBytes pb(0);
  // After resizing - new zero is written despite there being nothing to copy.
  pb.resize(20);
  EXPECT_EQ(0, pb[0]);
}

TEST(PaddedBytesTest, TestFillWithoutReserve) {
  PaddedBytes pb;
  for (size_t i = 0; i < 170; ++i) {
    pb.push_back(i);
  }
  EXPECT_EQ(170, pb.size());
  EXPECT_GE(pb.capacity(), 170);
}

TEST(PaddedBytesTest, TestFillWithExactReserve) {
  PaddedBytes pb;
  pb.reserve(170);
  for (size_t i = 0; i < 170; ++i) {
    pb.push_back(i);
  }
  EXPECT_EQ(170, pb.size());
  EXPECT_EQ(pb.capacity(), 170);
}

TEST(PaddedBytesTest, TestFillWithMoreReserve) {
  PaddedBytes pb;
  pb.reserve(171);
  for (size_t i = 0; i < 170; ++i) {
    pb.push_back(i);
  }
  EXPECT_EQ(170, pb.size());
  EXPECT_GT(pb.capacity(), 170);
}

// Can assign() a subset of the valid data.
TEST(PaddedBytesTest, TestAssignFromWithin) {
  PaddedBytes pb;
  pb.reserve(256);
  for (size_t i = 0; i < 256; ++i) {
    pb.push_back(i);
  }
  pb.assign(pb.data() + 64, pb.data() + 192);
  EXPECT_EQ(128, pb.size());
  for (size_t i = 0; i < 128; ++i) {
    EXPECT_EQ(i + 64, pb[i]);
  }
}

// Can assign() a range with both valid and previously-allocated data.
TEST(PaddedBytesTest, TestAssignReclaim) {
  PaddedBytes pb;
  pb.reserve(256);
  for (size_t i = 0; i < 256; ++i) {
    pb.push_back(i);
  }

  const uint8_t* mem = pb.data();
  pb.resize(200);
  // Just shrank without reallocating
  EXPECT_EQ(mem, pb.data());
  EXPECT_EQ(256, pb.capacity());

  // Reclaim part of initial allocation
  pb.assign(pb.data() + 100, pb.data() + 240);
  EXPECT_EQ(140, pb.size());

  for (size_t i = 0; i < 140; ++i) {
    EXPECT_EQ(i + 100, pb[i]);
  }
}

// Can assign() smaller and larger ranges outside the current allocation.
TEST(PaddedBytesTest, TestAssignOutside) {
  PaddedBytes pb;
  pb.resize(400);
  std::iota(pb.begin(), pb.end(), 1);

  std::vector<uint8_t> small(64);
  std::iota(small.begin(), small.end(), 500);

  pb.assign(small.data(), small.data() + small.size());
  EXPECT_EQ(64, pb.size());
  for (size_t i = 0; i < 64; ++i) {
    EXPECT_EQ((i + 500) & 0xFF, pb[i]);
  }

  std::vector<uint8_t> large(1000);
  std::iota(large.begin(), large.end(), 600);

  pb.assign(large.data(), large.data() + large.size());
  EXPECT_EQ(1000, pb.size());
  for (size_t i = 0; i < 1000; ++i) {
    EXPECT_EQ((i + 600) & 0xFF, pb[i]);
  }
}

}  // namespace
}  // namespace jxl
