require 'spec_helper'

describe OllamaChat::Utils::OrderedQueue do
  subject(:queue) { described_class.new }

  describe '#initialize' do
    it 'creates an empty queue' do
      expect(queue).to be_empty
    end
  end

  describe '#push' do
    it 'adds an item to the queue' do
      queue.push(1, 'first')
      expect(queue).not_to be_empty
    end

    it 'maintains min-heap ordering by ID' do
      queue.push(3, 'third')
      queue.push(1, 'first')
      queue.push(2, 'second')

      expect(queue.pop).to eq([1, 'first'])
      expect(queue.pop).to eq([2, 'second'])
      expect(queue.pop).to eq([3, 'third'])
    end

    it 'supports tuple IDs for ordering' do
      queue.push([1, 3], 'thread 1 chunk 3')
      queue.push([1, 1], 'thread 1 chunk 1')
      queue.push([2, 1], 'thread 2 chunk 1')
      queue.push([1, 2], 'thread 1 chunk 2')

      expect(queue.pop).to eq([[1, 1], 'thread 1 chunk 1'])
      expect(queue.pop).to eq([[1, 2], 'thread 1 chunk 2'])
      expect(queue.pop).to eq([[1, 3], 'thread 1 chunk 3'])
      expect(queue.pop).to eq([[2, 1], 'thread 2 chunk 1'])
    end

    it 'handles duplicate IDs' do
      queue.push(1, 'a')
      queue.push(1, 'b')

      first = queue.pop
      second = queue.pop

      expect(first[0]).to eq(1)
      expect(second[0]).to eq(1)
      expect([first[1], second[1]].sort).to eq(%w[a b])
    end
  end

  describe '#peek' do
    it 'returns nil when empty' do
      expect(queue.peek).to be_nil
    end

    it 'returns the lowest ID item without removing it' do
      queue.push(2, 'second')
      queue.push(1, 'first')

      expect(queue.peek).to eq([1, 'first'])
      expect(queue).not_to be_empty
      expect(queue.peek).to eq([1, 'first'])
    end
  end

  describe '#pop' do
    it 'returns nil when empty' do
      expect(queue.pop).to be_nil
    end

    it 'removes and returns the lowest ID item' do
      queue.push(1, 'first')
      result = queue.pop
      expect(result).to eq([1, 'first'])
      expect(queue).to be_empty
    end

    it 'pops items in ascending ID order' do
      (1..10).to_a.shuffle.each do |id|
        queue.push(id, "item #{id}")
      end

      (1..10).each do |id|
        expect(queue.pop).to eq([id, "item #{id}"])
      end
    end
  end

  describe '#empty?' do
    it 'returns true for a new queue' do
      expect(queue).to be_empty
    end

    it 'returns false after pushing an item' do
      queue.push(1, 'item')
      expect(queue).not_to be_empty
    end

    it 'returns true after popping all items' do
      queue.push(1, 'item')
      queue.pop
      expect(queue).to be_empty
    end
  end

  describe '#wait' do
    it 'signals when an item is pushed' do
      signaled = false

      consumer = Thread.new do
        result = queue.wait
        signaled = true
        result
      end

      sleep 0.1
      queue.push(23, 'item')
      consumer.join(2)

      expect(signaled).to be true
      expect(consumer).not_to be_alive
    end
  end

  describe 'thread safety' do
    it 'handles concurrent pushes correctly' do
      num_threads = 5
      items_per_thread = 100
      threads = []

      num_threads.times do |t|
        threads << Thread.new do
          items_per_thread.times do |i|
            id = t * items_per_thread + i
            queue.push(id, "thread-#{t}-item-#{i}")
          end
        end
      end

      threads.each(&:join)

      # Collect all results and verify ordering
      results = []
      until queue.empty?
        results << queue.pop
      end

      expect(results.size).to eq(num_threads * items_per_thread)

      # Verify IDs are in ascending order
      ids = results.map(&:first)
      expect(ids).to eq(ids.sort)
    end

    it 'handles concurrent pushes and pops correctly' do
      num_items = 100
      done = false
      results = []

      producer = Thread.new do
        num_items.times do |i|
          queue.push(i, "item-#{i}")
          sleep 0.001
        end
        done = true
      end

      consumer = Thread.new do
        loop do
          item = queue.pop
          if item
            results << item
          elsif done && queue.empty?
            break
          else
            sleep 0.001
          end
        end
      end

      producer.join
      consumer.join(5)

      expect(results.size).to eq(num_items)
      ids = results.map(&:first)
      expect(ids).to eq(ids.sort)
    end
  end

  describe 'heap integrity' do
    it 'maintains heap property after multiple push/pop cycles' do
      queue.push(5, 'five')
      queue.push(3, 'three')
      queue.push(8, 'eight')
      queue.pop # removes 3

      queue.push(1, 'one')
      queue.push(4, 'four')

      expect(queue.pop).to eq([1, 'one'])
      expect(queue.pop).to eq([4, 'four'])
      expect(queue.pop).to eq([5, 'five'])
      expect(queue.pop).to eq([8, 'eight'])
      expect(queue).to be_empty
    end

    it 'handles large number of items efficiently' do
      size = 1000
      shuffled = (1..size).to_a.shuffle

      shuffled.each do |id|
        queue.push(id, id)
      end

      (1..size).each do |id|
        expect(queue.pop).to eq([id, id])
      end
    end
  end

  describe 'complex scenario with 4 threads' do
    it 'handles realistic interleaved TTS thread data' do
      # Simulate realistic insertion order where threads start sequentially
      # but data arrives interleaved due to varying network latency.
      # Thread 4 starts after Thread 1 has already finished.

      queue.push([1, 1], :started)
      queue.push([1, 2], 't1-chunk1')
      queue.push([2, 1], :started)
      queue.push([1, 3], 't1-chunk2')
      queue.push([3, 1], :started)
      queue.push([2, 2], 't2-chunk1')
      queue.push([1, 4], 't1-chunk3')
      queue.push([1, 5], :finished)
      queue.push([4, 1], :started)
      queue.push([3, 2], 't3-chunk1')
      queue.push([4, 2], 't4-chunk1')
      queue.push([2, 3], 't2-chunk2')
      queue.push([4, 3], 't4-chunk2')
      queue.push([3, 3], 't3-chunk2')
      queue.push([2, 4], 't2-chunk3')
      queue.push([2, 5], 't2-chunk4')
      queue.push([2, 6], :finished)
      queue.push([3, 4], 't3-chunk3')
      queue.push([4, 4], 't4-chunk3')
      queue.push([3, 5], :finished)
      queue.push([4, 5], 't4-chunk4')
      queue.push([4, 6], :finished)

      expected = [
        [[1, 1], :started],
        [[1, 2], 't1-chunk1'],
        [[1, 3], 't1-chunk2'],
        [[1, 4], 't1-chunk3'],
        [[1, 5], :finished],
        [[2, 1], :started],
        [[2, 2], 't2-chunk1'],
        [[2, 3], 't2-chunk2'],
        [[2, 4], 't2-chunk3'],
        [[2, 5], 't2-chunk4'],
        [[2, 6], :finished],
        [[3, 1], :started],
        [[3, 2], 't3-chunk1'],
        [[3, 3], 't3-chunk2'],
        [[3, 4], 't3-chunk3'],
        [[3, 5], :finished],
        [[4, 1], :started],
        [[4, 2], 't4-chunk1'],
        [[4, 3], 't4-chunk2'],
        [[4, 4], 't4-chunk3'],
        [[4, 5], 't4-chunk4'],
        [[4, 6], :finished]
      ]

      results = []
      loop do
        item = queue.pop
        break unless item
        results << item
      end

      expect(results).to eq(expected)
    end
  end
end
