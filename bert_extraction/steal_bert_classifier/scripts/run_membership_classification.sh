# coding=utf-8
# Copyright 2018 The Google AI Language Team Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#!/bin/bash

# For SST-2 experiments replace MNLI with SST-2 for $TASK_NAME
export BERT_DIR=/path/to/bert/uncased_L-24_H-1024_A-16
export GLUE_DIR=/path/to/glue
export TASK_NAME="MNLI"

export WIKI_MEMBERSHIP_DATA_DIR=/path/to/wiki/membership/dataset/
export RANDOM_MEMBERSHIP_DATA_DIR=/path/to/random/membership/dataset/
export WIKI_DATA_DIR=/path/to/wiki/extraction/data
export RANDOM_DATA_DIR=/path/to/random/extraction/data

export VICTIM_MODEL=/path/to/victim/model/checkpoint
export OUTPUT_DIR=/path/to/output/membership/classifier/checkpoints

# Task-specific variables

if ["$TASK_NAME" = "MNLI"]; then
  DEV_FILE_NAME="dev_matched.tsv"
else:
  DEV_FILE_NAME="dev.tsv"
fi

# STEP 1.1
# Use the original dataset and WIKI dataset to construct a membership classification dataset
python -m language.bert_extraction.steal_bert_classifier.data_generation.build_membership_dataset \
  --original_train_data=$GLUE_DIR/$TASK_NAME/train.tsv \
  --original_dev_data=$GLUE_DIR/$TASK_NAME/$DEV_FILE_NAME \
  --attack_data=$WIKI_DATA_DIR/new_train_sents.tsv \
  --output_path=$WIKI_MEMBERSHIP_DATA_DIR

# STEP 1.2
# Use the original dataset and RANDOM dataset to construct a membership classification dataset
python -m language.bert_extraction.steal_bert_classifier.data_generation.build_membership_dataset \
  --original_train_data=$GLUE_DIR/$TASK_NAME/train.tsv \
  --original_dev_data=$GLUE_DIR/$TASK_NAME/$DEV_FILE_NAME \
  --attack_data=$RANDOM_DATA_DIR/new_train_sents.tsv \
  --output_path=$RANDOM_MEMBERSHIP_DATA_DIR

# STEP 1.3
# Construct auxiliary evaluation sets (RANDOM, SHUFFLE) to check the robustness of the membership classifier
python -m language.bert_extraction.steal_bert_classifier.data_generation.build_aux_membership \
  --membership_dev_data=$WIKI_MEMBERSHIP_DATA_DIR/dev.tsv \
  --random_membership_dev_data=$RANDOM_MEMBERSHIP_DATA_DIR/dev.tsv \
  --aux_path=$WIKI_MEMBERSHIP_DATA_DIR

# STEP 2
# Train a membership classifier on the WIKI membership train split and evaluate on WIKI membership dev split
python -m language.bert_extraction.steal_bert_classifier.models.run_classifier_membership \
  --task_name=$TASK_NAME \
  --exp_name="train_membership_classifier" \
  --do_train=true \
  --do_eval=true \
  --do_lower_case=true \
  --save_checkpoints_steps=5000 \
  --data_dir=$WIKI_MEMBERSHIP_DATA_DIR \
  --vocab_file=$BERT_DIR/vocab.txt \
  --bert_config_file=$BERT_DIR/bert_config.json \
  --init_checkpoint=$VICTIM_MODEL \
  --max_seq_length=128 \
  --train_batch_size=32 \
  --learning_rate=3e-4 \
  --num_train_epochs=1.0 \
  --output_dir=$OUTPUT_DIR \
  --membership_features_str="last_plus_logits"

# STEP 3
# Evaluate the trained membership classifier on auxiliary test sets

# RANDOM auxiliary validation set
python -m language.bert_extraction.steal_bert_classifier.models.run_classifier_membership \
  --task_name=$TASK_NAME \
  --exp_name="train_membership_classifier" \
  --do_train=false
  --do_eval=true \
  --do_lower_case=true \
  --save_checkpoints_steps=5000 \
  --data_dir=$WIKI_MEMBERSHIP_DATA_DIR/random \
  --vocab_file=$BERT_DIR/vocab.txt \
  --bert_config_file=$BERT_DIR/bert_config.json \
  --init_checkpoint=$VICTIM_MODEL \
  --max_seq_length=128 \
  --output_dir=$OUTPUT_DIR \
  --membership_features_str="last_plus_logits"

# SHUFFLE auxiliary validation set
python -m language.bert_extraction.steal_bert_classifier.models.run_classifier_membership \
  --task_name=$TASK_NAME \
  --exp_name="train_membership_classifier" \
  --do_train=false
  --do_eval=true \
  --do_lower_case=true \
  --save_checkpoints_steps=5000 \
  --data_dir=$WIKI_MEMBERSHIP_DATA_DIR/shuffle \
  --vocab_file=$BERT_DIR/vocab.txt \
  --bert_config_file=$BERT_DIR/bert_config.json \
  --init_checkpoint=$VICTIM_MODEL \
  --max_seq_length=128 \
  --output_dir=$OUTPUT_DIR \
  --membership_features_str="last_plus_logits"
