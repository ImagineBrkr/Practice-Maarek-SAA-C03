# SQS Queue

resource "aws_sqs_queue" "sqs_queue_sales" {
  name                       = "sales-queu"
  delay_seconds              = 90     #Delay for the delivery
  max_message_size           = 262144 #Max 256 Kb
  message_retention_seconds  = 86400  # 1 day
  receive_wait_time_seconds  = 0      # It won't wait
  visibility_timeout_seconds = 60     # The message won't be called again during this time

  sqs_managed_sse_enabled = true # SSE managed by SQS
}

resource "aws_sqs_queue" "sqs_queue_ships_fifo" {
  name                        = "ships-queue.fifo" # Must have .fifo at the end
  fifo_queue                  = true
  content_based_deduplication = true #De duplicates the messages

  delay_seconds              = 90     #Delay for the delivery
  max_message_size           = 262144 #Max 256 Kb
  message_retention_seconds  = 86400  # 1 day
  receive_wait_time_seconds  = 0      # It won't wait
  visibility_timeout_seconds = 60     # The message won't be called again during this time


  sqs_managed_sse_enabled = true # SSE managed by SQS
}


# SNS Topic


resource "aws_sns_topic" "sns_topic_transacions" {
  name = "transactions-topic"
  # fifo_topic                  = true # Can also be FIFO
  # content_based_deduplication = true # FIFO Topics can use deduplication
}

resource "aws_sns_topic_subscription" "sns_topic_sqs_subscription" {
  topic_arn = aws_sns_topic.sns_topic_transacions.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sqs_queue_sales.arn
}


# Kinesis Data Stream


resource "aws_kinesis_stream" "kinesis_stream_views" {
  name = "views-kinesis-stream"

  retention_period = 48

  stream_mode_details {
    stream_mode = "PROVISIONED" #Can also be on demand
  }
  shard_count = 1
}