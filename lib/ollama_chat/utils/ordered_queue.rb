# A thread-safe priority queue backed by a Min-Heap.
#
# This class ensures that items are retrieved in the order of their
# IDs, which can be tuples like [thread_id, chunk_id].
class OllamaChat::Utils::OrderedQueue
  # Initializes a new OrderedQueue.
  def initialize
    @heap = []
    @mutex = Mutex.new
    @cv = ConditionVariable.new
  end

  # Pushes an item into the queue.
  #
  # @param id [Array<Integer>, Integer] the ID for ordering (e.g., [thread_id, chunk_id])
  # @param payload [Object] the data associated with the ID
  def push(id, payload)
    @mutex.synchronize do
      id.extend(Comparable) rescue nil
      @heap << [id, payload]
      heapify_up(@heap.size - 1)
      @cv.signal
    end
  end

  # Peeks at the item with the lowest ID without removing it.
  #
  # @return [Array, nil] the [id, payload] pair or nil if empty
  def peek
    @mutex.synchronize { @heap[0] }
  end

  # Removes and returns the item with the lowest ID.
  #
  # @return [Array, nil] the [id, payload] pair or nil if empty
  def pop
    @mutex.synchronize { extract_min }
  end

  # Checks if the queue is empty.
  #
  # @return [Boolean] true if empty
  def empty?
    @mutex.synchronize { @heap.empty? }
  end

  # Waits for a signal from a producer thread.
  def wait
    @mutex.synchronize { @cv.wait(@mutex) }
  end

  private

  # Removes the minimum element from the heap.
  #
  # @return [Array, nil] the [id, payload] pair or nil if empty
  def extract_min
    min = @heap[0]
    if @heap.size > 1
      last = @heap.pop
      @heap[0] = last
      heapify_down(0)
    else
      @heap.clear
    end
    min
  end

  # Restores the min-heap property by moving an element up.
  def heapify_up(index)
    while index > 0
      parent = (index - 1) / 2
      break if @heap[index][0] >= @heap[parent][0]

      @heap[index], @heap[parent] = @heap[parent], @heap[index]
      index = parent
    end
  end

  # Restores the min-heap property by moving an element down.
  def heapify_down(index)
    size = @heap.size
    while true
      smallest = index
      left = 2 * index + 1
      right = 2 * index + 2

      smallest = left if left < size && @heap[left][0] < @heap[smallest][0]
      smallest = right if right < size && @heap[right][0] < @heap[smallest][0]

      break if smallest == index

      @heap[index], @heap[smallest] = @heap[smallest], @heap[index]
      index = smallest
    end
  end
end
